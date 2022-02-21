# purescript-mermaid-cli


Since [mermaidjs/mermaid.cli](https://github.com/mermaidjs/mermaid.cli) looks like it is not maintained anymore,
re-written with purescript for my personal use. Currenty uses
puppeteer 13.3.2 and mermaid 8.4.2.

## Build

```
$ spago build
$ npm install
```

## Usage

```
$ ./mmdc --help
mmdc - cli command for mermaid

Usage: -- (-i|--input PATH) [-o|--output PATH] [-t|--theme THEME]
          [--cdn-version VER] [--debug]

Available options:
  -i,--input PATH          Input mermaid file. Required.
  -o,--output PATH         Output file. It should be either svg, png. Optional.
                           Default: input + ".svg"
  -t,--theme THEME         Theme of the chart, could be default, forest, dark or
                           neutral (default: default)
  --cdn-version VER        You can specify which version of mermaid.js to use.
                           Will use official CDN. (default: "8.4.2")
  --debug                  Show the browser and don't close it atomatically even
                           after successfully created.
  -h,--help                Show this help text
$ ./mmdc -i sample/sequence_diagram.mmd -o seq.png -t dark
```
