# content.example

Amostra versionada da árvore servida em `/srv/cdn`. O conteúdo real fica em
`content/` (fora do Git). Para começar localmente:

```
cdn-seed   # copia content.example/ -> content/
```

Estrutura de exemplo:

```
content.example/
├── css/site.a1b2c3d4.css          # nome com hash => cache imutável
├── js/app.4d3c2b1a.js
├── vendor/bootstrap/5.3.3/bootstrap.min.css
├── vendor/mermaid/               # mermaid.min.js (self-hosted)
├── fonts/                        # *.woff2
├── img/logo.svg
└── robots.txt
```
