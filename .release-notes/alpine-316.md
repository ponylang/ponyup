## Update Dockerfile to Alpine 3.16

The ponyup Docker container has been updated from being based on Alpine 3.12 to Alpine 3.16. This shouldn't be a breaking change for pretty much anyone, but might be if you are using the ponyup image as a base for other images and some package you rely on was removed from Alpine 3.16.

Alpine 3.12 is no longer supported. Alpine 3.16 is supported through 2024.
