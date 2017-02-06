# p4pubsub


## Docker Container

### Building

    cd docker
    docker build -t p4image .

### Running

Make sure to start the container with `--privileged`:

    docker run --privileged -d --name p4 --hostname p4 p4image

If you want to mount a local diretory in the container, you can use the `-v` argument. For example, to mount your local `~/src` directory in the container, run:

    docker run --privileged -d --name p4 --hostname p4 -v $HOME/src:/root/src p4image

You can then enter the container:

    docker exec -it p4 bash
