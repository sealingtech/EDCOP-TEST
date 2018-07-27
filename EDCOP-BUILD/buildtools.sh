#/bin/bash

RELEASE="0.5.0"
ENV="dev"

PATH_TO_EDCOPBUILD=/root/build

REPO_INDEX="http://repos.sealingtech.org/dev"


cd $PATH_TO_EDCOPBUILD
curl -s https://api.github.com/orgs/sealingtech/repos?per_page=200 | python -c $'import json, sys, os\nfor repo in json.load(sys.stdin):\n if repo["name"].startswith("EDCOP-"): os.system("git clone -b master " + repo["clone_url"])'



#Build containers with all the necessary versions
echo "******Building containers*******"
for i in EDCOP-* 
do
  tool_name=$(echo $i | sed  s/EDCOP-// | tr '[:upper:]' '[:lower:]')
  echo "*******Building container: $tool_name*********"
  container_tag="gcr.io/edcop-$ENV/$tool_name:$RELEASE"
  if test -e $i/container/Dockerfile
  then
     docker build -t $container_tag $i/container/
     docker push $container_tag
  fi
done



#All custom images need the version to be over-ridden
yq w -i EDCOP-SURICATA/suricata/values.yaml images.suricata "gcr.io/edcop-$ENV/suricata:$RELEASE"
yq w -i EDCOP-BRO/bro/values.yaml images.bro "gcr.io/edcop-$ENV/bro:$RELEASE"
yq w -i EDCOP-MOLOCH/moloch/values.yaml images.moloch "gcr.io/edcop-$ENV/moloch:$RELEASE"


echo "******Packaging Charts*******"
for i in $(find . -name Chart.yaml | grep -v EDCOP-TOOLS | sed  s/Chart.yaml//g)
do
  tool_name=$(echo $i | sed  s/EDCOP-// | tr '[:upper:]' '[:lower:]')
  echo "*******Packaging : $tool_name*********"
  cp -f $i/$tool_name/README.md $tool_name/
  helm package --version $RELEASE $i
done
mv *.tgz charts
mkdir charts

helm repo index charts/ --url $REPO_INDEX

rm -rf EDCOP-*


