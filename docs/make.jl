using Scanivalve
using Documenter

DocMeta.setdocmeta!(Scanivalve, :DocTestSetup, :(using Scanivalve); recursive=true)

makedocs(;
    modules=[Scanivalve],
    authors="Paulo Jabardo <pjabardo@ipt.br>",
    repo="https://github.com/pjsjipt/Scanivalve.jl/blob/{commit}{path}#{line}",
    sitename="Scanivalve.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
