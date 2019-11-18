{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "mermaid-cli"
, dependencies =
    [ "assert"
    , "console"
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
