#!/bin/bash
set -euo pipefail

### ---- ###

echo "Switch back to master"
git checkout master
git reset --hard origin/master

### ---- ###

version=$(curl -s "https://lv.luzifer.io/catalog-api/openfire/latest.txt?p=version")
versionVar=$(echo "${version}" | sed 's/\./_/g')
grep -q "OPENFIRE_VERSION=${versionVar} " Dockerfile && exit 0 || echo "Update required"

sed -Ei \
	-e "s/OPENFIRE_VERSION=[0-9_]+/OPENFIRE_VERSION=${versionVar}/" \
	Dockerfile

### ---- ###

echo "Testing image build and run..."

function cleanup() {
	docker rm -f luzifer-openfire
}

docker run -d --name luzifer-openfire $(docker build -q .)
trap cleanup EXIT

sleep 5 # Container needs a moment to spin up
docker exec -ti luzifer-openfire sh -exc 'apk --no-cache add curl && curl -sL localhost:9090/index.jsp | grep -q "Openfire Setup"'

### ---- ###

echo "Updating repository..."
git add Dockerfile
git -c user.name='Travis Automated Update' -c user.email='travis@luzifer.io' \
	commit -m "Openfire ${version}"
git tag ${version}

git push -q https://${GH_USER}:${GH_TOKEN}@github.com/luzifer-docker/openfire master --tags
