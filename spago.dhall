{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "purescript-mermaid-cli"
, dependencies =
  [ "console"
  , "aff"
  , "control"
  , "either"
  , "foreign"
  , "maybe"
  , "node-buffer"
  , "prelude"
  , "strings"
  , "effect"
  , "node-fs-aff"
  , "node-path"
  , "optparse"
  , "psci-support"
  , "smolder"
  , "toppokki"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
