# wan-2.2-t2v-paperspace

Docker Login:
```
docker login -u raphael2057
```

build docker image: 
```
docker buildx create --use
docker buildx build --platform linux/amd64 -t raphael2057/torch24-cu121:latest --load .
```

run the container:
```
docker run -it --name torch24 --rm raphael2057/torch24-cu121:latest /bin/sh
```

push the image:
```
docker push raphael2057/torch24-cu121:latest
```