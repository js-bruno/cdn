{ pkgs, ... }:
let
  # caddy-webdav has no tags/releases, so we pin by commit (same ref as CI).
  webdavRef = "fa2f366b0d75e54c2e381c0aefc3a8df8bf5794b";
in
{
  packages = with pkgs; [
    caddy # plain caddy: hash-password / fmt / validate / export-template
    xcaddy # builds ./bin/caddy WITH the webdav plugin
    go
    rsync
    openssh
    curl
    jq
    nixfmt-rfc-style
  ];

  env.CADDY_WEBDAV_REF = webdavRef;

  scripts = {
    cdn-build.exec = ''
      mkdir -p bin
      echo "building caddy + webdav ($CADDY_WEBDAV_REF) -> ./bin/caddy"
      xcaddy build --with "github.com/mholt/caddy-webdav@$CADDY_WEBDAV_REF" --output bin/caddy
      ./bin/caddy version
    '';

    cdn-seed.exec = ''
      rm -rf content
      cp -r content.example content
      echo "content/ criado a partir de content.example/"
    '';

    cdn-hash.exec = ''
      caddy hash-password --plaintext "$1"
    '';

    cdn-fmt.exec = ''
      caddy fmt --overwrite Caddyfile
      caddy fmt --overwrite Caddyfile.dev
    '';

    cdn-validate.exec = ''
      if [ ! -x bin/caddy ]; then
        echo "rode 'cdn-build' primeiro — o plugin webdav é necessário para validar" >&2
        exit 1
      fi
      bin/caddy validate --config Caddyfile --adapter caddyfile
    '';

    cdn-dev.exec = ''
      if [ ! -x bin/caddy ]; then
        echo "bin/caddy não encontrado — rode 'cdn-build' primeiro" >&2
        exit 1
      fi
      exec bin/caddy run --config Caddyfile.dev --adapter caddyfile
    '';

    cdn-deploy.exec = ''
      deploy/scripts/deploy-rsync.sh "$@"
    '';
  };

  enterShell = ''
    echo "cdn | caddy + webdav (devenv)"
    echo "  cdn-build     -> compila ./bin/caddy com o plugin webdav"
    echo "  cdn-seed      -> copia content.example/ para content/"
    echo "  cdn-hash      -> gera bcrypt para ADMIN_PASSWORD_HASH"
    echo "  cdn-fmt       -> formata os Caddyfiles"
    echo "  cdn-validate  -> valida o Caddyfile de produção"
    echo "  cdn-dev       -> sobe Caddy local (:8080 público, :8081 admin)"
    echo "  cdn-deploy    -> publica content/ no VPS (DEPLOY_HOST)"
  '';
}
