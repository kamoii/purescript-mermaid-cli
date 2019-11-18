module Main where

import Options.Applicative
import Prelude

import Control.Alternative (class Alternative, (<|>))
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe, optional)
import Data.Semigroup ((<>))
import Data.String as String
import Effect (Effect)
import Effect.Aff (Aff, error, launchAff_, throwError)
import Effect.Class.Console (log)
import Foreign (unsafeFromForeign, unsafeToForeign)
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Node.Path (FilePath)
import Node.Path as Path
import Text.Smolder.HTML as S
import Text.Smolder.HTML.Attributes as A
import Text.Smolder.Markup (text, (!))
import Text.Smolder.Renderer.String (render)
import Toppokki as T

data Theme
  = DefaultTheme
  | DarkTheme
  | ForestTheme
  | NeutralTheme

instance showTheme :: Show Theme where
  show = case _ of
    DefaultTheme -> "default"
    DarkTheme    -> "dark"
    ForestTheme  -> "forest"
    NeutralTheme -> "neutral"

type Options =
  { input :: FilePath
  , output :: Maybe FilePath
  , theme :: Theme
  , debug :: Boolean
  }

optsParser :: Parser Options
optsParser =
  { input: _, output: _, theme: _, debug: _}
  <$> strOption ( long "input" <> short 'i' <> metavar "PATH" <> help "Input mermaid file. Required." )
  <*> do optional $ strOption ( long "output" <> short 'o' <> metavar "PATH" <> help "Output file. It should be either svg, png. Optional. Default: input + \".svg\"" )
  <*> option themeR ( long "theme" <> short 't' <> help "Theme of the chart, could be default, forest, dark or neutral" <> showDefault <> value DefaultTheme <> metavar "THEME" )
  <*> switch ( long "debug" <> help "Show the browser and don't close it atomatically even after successfully created." <> showDefault )
  where
    themeR :: ReadM Theme
    themeR = eitherReader $ case _ of
      "default" -> Right DefaultTheme
      "dark"    -> Right DarkTheme
      "forest"  -> Right ForestTheme
      "neutral" -> Right NeutralTheme
      s         -> Left $ "Invalid theme: `" <> s <> "`"

optsInfo :: ParserInfo Options
optsInfo =
  info (optsParser <**> helper)
  ( fullDesc
    <> progDesc "Print a greeting for TARGET"
    <> header "mmdc - a test for purescript-optparse"
  )

cdn :: String
cdn = "https://unpkg.com/mermaid@8.4.2/dist/mermaid.min.js"

data OutputExt
  = SVG
  | PNG

-- headless が常駐って可能なのか？
main :: Effect Unit
main = do
  opts <- execParser optsInfo
  let output = fromMaybe (changeExtTo ".svg" opts.input) opts.output
  outputExt <- case Path.extname output of
    ".svg" -> pure SVG
    ".png" -> pure PNG
    _      -> throwError (error "Unsupported output extension.")
  launchAff_ do
    let headless = not opts.debug
    let doClose  = not opts.debug
    definition <- FS.readTextFile UTF8 opts.input
    browser <- T.launch { headless }
    svg <- mermaidRender browser opts.theme definition
    case outputExt of
      SVG -> FS.writeTextFile UTF8 output svg
      PNG -> convertSvgToPng browser output svg
    when doClose $ T.close browser

-- | MermaidAPI を利用してSVGを得る。
-- | 一時的に画面には(hiddenな)DOMが追加されるが、最終的には何もない状態。
-- | ビューポートのサイズはレンダリングに影響を与えない。
mermaidRender :: T.Browser -> Theme -> String -> Aff String
mermaidRender browser theme definition = do
  page <- T.newPage browser
  T.setContent indexHtml page
  svg' <- T.unsafeEvaluateWithArgs renderFn [unsafeToForeign definition] page
  pure $ unsafeFromForeign svg'
  where
    renderFn :: String
    renderFn = "(definition) => { return window.mermaid.render('mmdc', definition); }"

    -- smolder は script や style のコンテンツだろうがエスケープをかける。
    -- 多分制御する方法はないので、古き汚ない placeholder + replace 方式で。
    indexHtml :: String
    indexHtml =
      template
      # render
      # String.replace (String.Pattern initJsHolder) (String.Replacement initJs)
      # String.replace (String.Pattern styleHolder) (String.Replacement style)
      where
        initJsHolder = "__INIT_JS__"
        initJs = "window.mermaid.initialize({theme: '" <> show theme <> "', startOnLoad: false});"
        styleHolder = "__STYLE__"
        style = ""

        template =
          S.html do
            S.head do
              S.script ! A.src cdn $ text ""
              S.script $ text initJsHolder
              S.style $ text styleHolder
            S.body do
              pure unit

-- | SVG を png 画像に変換する。
-- | ビューポートは svg 要素以上の大きさが必要。生成される png 画像のサイズは変わらないが、
-- | ビューポートからはみ出た部分は白抜きになる。
-- | ?? viewport サイズ無指定の場合はどうなる？
convertSvgToPng :: T.Browser -> FilePath -> String -> Aff Unit
convertSvgToPng browser output svg = do
  page <- T.newPage browser
  T.setContent indexHtml page
  clip' <- T.unsafePageEval (T.Selector "svg") svgRect page
  let clip = unsafeFromForeign clip'
  _ <- T.screenshot { path: output, clip } page
  pure unit
  where
    indexHtml = "<!DOCTYPE html>\n<html><body>" <> svg <> "</body></html>"
    svgRect = "(svg) => { const react = svg.getBoundingClientRect(); return { x: react.left, y: react.top, width: react.width, height: react.height } }"

-- `ext` must inclide '.' (e.g. `.png`)
changeExtTo :: String -> FilePath -> FilePath
changeExtTo ext path =
  fromMaybe
    path
    (String.stripSuffix (String.Pattern $ Path.extname path) path)
    <> ext


{- | Note about Mermaid API

render 関数のドキュメントが分かりにくいし一部間違っている。
まずそもそもが svg を生成するためだけのものであり、一時的に DOMを生成するが、
レンダリングして svg が得られたら DOMは削除する。
svg は同期的に得られる。cb 渡すのはオプショナル(ただグラフの種類によっては
svg 以外追加の情報を引数に cb が呼ばれる)
返り値は svg。なので id, txt 渡せば基本的に svg が得られる。

    id the id of the element to be rendered
    txt the graph definition
    cb callback which is called after rendering is finished with the svg code as inparam.
    container selector to element in which a div with the graph temporarily will be inserted. In one is provided a hidden div will be inserted in the body of the page instead. The element will be removed when rendering is completed.

 * container は selector と書かれている、要素を渡す必要がある
 * container を渡した場合、その下に id=('d'+`id`)を持つ div が作られその下に svg が挿入される
 * container が渡さなかった場合、body直下に id=('d'+`id`)を持つ div が作られその下に svg が挿入される
 * svg要素自体が id=`id` を持つ
 * style は svg 要素の下に 挿入され selector は #`id` を

style が svg の中に入るので svg さえあれば再現できるはず
container が制御できる理由は何？縦横のサイズ制御？

-}
