#!/bin/bash

# Description :

# This scripts requires a list of base images in the current working directory and a Dockerfile.
# Using Docker in Docker we run docker builds in parallel in their own containers.  

declare -a containers 

echo "Starting Docker in Docker"
docker run --privileged --name dind -d docker:stable-dind

echo "====================="
echo "Building Dockerfile :"
echo "====================="
cat Dockerfile
echo "====================="
echo "Using Base images :  "
echo "====================="
cat base_images 
echo "====================="

for image in `cat base_images`
do
    tag=`echo ${image} |cut -d':' -f2`
    containers=("${containers[@]}" "Dockerfile.${tag}")

    echo "--> Creating Dockerfile.${tag}"
    cp Dockerfile Dockerfile.${tag}
    echo "--> Replacing FROM command with FROM ${image}"
    sed -i "/FROM/c FROM ${image}" Dockerfile.${tag} 
    cat Dockerfile.${tag} |grep FROM

    echo "--> Starting Build : Dockerfile.${tag}"
    docker rm -f Dockerfile.${tag}

    # naming the container after the Dockerfile
    docker run -d --name Dockerfile.${tag} --link dind:docker -v $(pwd):/tmp -w /tmp docker:edge build -t verified/${tag} --no-cache -f Dockerfile.${tag} .

done

echo "Waiting for containers to finish ..."
docker wait "${containers[@]}"

for container in `echo "${containers[@]}"`
do
echo "---> Logs for $container build"
docker logs ${container} |tail -2
done
