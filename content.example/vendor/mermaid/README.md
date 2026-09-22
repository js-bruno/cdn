# mermaid (self-hosted)

Coloque aqui `mermaid.min.js` para o diagrama do admin ser servido pela própria CDN:

```
curl -fsSL https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js \
  -o vendor/mermaid/mermaid.min.js
```

O `browse.html` carrega `/vendor/mermaid/mermaid.min.js` e, se não existir,
cai no fallback do jsDelivr (conveniência para dev). Em produção, self-hosted.
