#!/usr/bin/env bash
# Jednorazowo: dodaje wszystkie repozytoria Rynku jako submoduły tego repozytorium.
# Uruchom w korzeniu świeżo sklonowanego rynek-platform (na Windowsie w Git Bash):
#   bash scripts/add-submodules.sh && git commit -m "Dodaj submoduły" && git push
# Adres bazowy można zmienić: ORG_URL=git@github.com:marketplace-e-commerce-i-uslugi bash scripts/add-submodules.sh
set -euo pipefail

ORG_URL="${ORG_URL:-https://github.com/marketplace-e-commerce-i-uslugi}"

REPOS=(
  rynek-api-gateway
  rynek-identity-service
  rynek-channel-service
  rynek-catalog-service
  rynek-media-service
  rynek-tiktok-integration-service
  rynek-feed-service
  rynek-search-service
  rynek-engagement-service
  rynek-chat-service
  rynek-cart-service
  rynek-order-service
  rynek-payment-service
  rynek-booking-service
  rynek-shipping-service
  rynek-notification-service
  rynek-analytics-service
  rynek-frontend
  rynek-infra
  rynek-contracts
  rynek-docs
)

for repo in "${REPOS[@]}"; do
  if [ -e "$repo/.git" ] || git config -f .gitmodules --get "submodule.$repo.url" > /dev/null 2>&1; then
    echo "pomijam $repo (już dodany)"
    continue
  fi
  git submodule add "$ORG_URL/$repo.git" "$repo"
done

# Śledź gałąź główną, żeby `git submodule update --remote` podciągało najnowsze zmiany.
for repo in "${REPOS[@]}"; do
  git config -f .gitmodules "submodule.$repo.branch" main
done

echo "Gotowe. Zatwierdź zmiany: git add .gitmodules && git commit -m 'Dodaj submoduły'"
