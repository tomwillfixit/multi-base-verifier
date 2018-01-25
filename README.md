# multi-base-verifier

As someone who builds Docker images for other teams to use it's important to ensure backwards compatibility is maintained.  Most paid registries offer this type of feature to automatically rebuild images when a base image is changed.  

If you are using your own registry it's possible to use "Docker in Docker" and a bit of bash to verify builds against multiple base images.

This is just a little POC. It should just work out of the box. 

## Usage

./MultiBaseVerifier.sh

## Output

![Alt Text](https://github.com/tomwillfixit/multi-base-verifier/blob/master/demo.gif)

