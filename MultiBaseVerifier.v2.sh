#!/bin/bash

# Description :

# This script will detect the repository name from the Dockerfile, query Docker Hub for a list of tags and verify the image build passes against each tag.

# Using Docker in Docker we run docker builds in parallel in their own containers. Each tag will get it's own container where the docker build command will run. 

echo "Extracting Repository and Tags from Dockerfile"
extract=$(cat Dockerfile |grep FROM |awk '{print $2}')
echo ${extract} 
repo=$(echo ${extract} |cut -d ":" -f1)

echo "Get list of tags from Docker Hub for repo : ${repo}"
url="https://registry.hub.docker.com/v2/repositories/library/${repo}/tags?page_size=1024"

IFS=$'\n' read -r -d '' -a tag_array \
  < <(set -o pipefail; curl -L -s --fail -k "$url" | jq -r '."results"[]["name"]' && printf '\0')

if [ -n "${tag_array}" ]; then
    echo "Tags found :"
    printf '%s\n' "${tag_array[@]}"
else
    echo "Unable to get a list of tags. This may be due to curl failing or failure to extract the tags from the Dockerfile."
    exit 3
fi

echo "Starting Docker in Docker"
docker run --privileged --name dind -d docker:stable-dind

echo "====================="
echo "Verifying Dockerfile :"
echo "====================="
cat Dockerfile
echo "====================="
echo "Using Images Tags :  "
echo "====================="
printf '%s\n' "${tag_array[@]}"
echo "====================="

for tag in $(printf '%s\n' "${tag_array[@]}")
do
    echo "--> Creating Dockerfile.${tag}"
    cp Dockerfile Dockerfile.${tag}
    echo "--> Replacing FROM command with FROM ${repo}${tag}"
    sed -i "/FROM/c FROM ${repo}:${tag}" Dockerfile.${tag} 
    cat Dockerfile.${tag} |grep FROM

    echo "--> Starting Build for tag : ${tag}"
    #remove previous container if it exists
    docker rm -f ${tag} 2>/dev/null

    # naming the container after the Dockerfile
    docker run -d --name ${tag} --link dind:docker -v $(pwd):/tmp -w /tmp docker:edge build -t verified/${tag} --no-cache -f Dockerfile.${tag} .

done

echo "Waiting for containers to finish ..."
docker wait "${tag_array[@]}"

for container in `echo "${tag_array[@]}"`
do
exit_code=$(docker inspect ${container} --format='{{.State.ExitCode}}')
if [ ${exit_code} -eq 0 ];then
    echo "[PASS] ... Dockerfile built successfully using FROM ${repo}:${container}"
    echo "---> Logs for $container build"
    docker logs ${container} |tail -2
else
    echo "[FAIL] ... Dockerfile failed to build using FROM ${repo}:${container}"
    echo "---> Logs for $container build"
    docker logs ${container} 
fi
echo "Removing container : ${container}"
docker rm -f ${container}
done

echo "=== Cleanup ==="
echo "Removing Docker in Docker container"
docker rm -f dind
