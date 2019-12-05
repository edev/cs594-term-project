# cs594-term-project
Term project for CS 594: Internetworking Protocols, Fall 2019 @ Portland State University. Assignment: design &amp; build an IRC-like protocol, with reference client &amp; server implementations.

**Note** I deliberately do not explain the inner workings of this project here in order to discourge students from copying this repository for their own term projects. However, the inner workings as well-documented in code comments for those who are interested.

## RFC

You will find the RFC in [rfc.txt](https://github.com/edev/cs594-term-project/blob/master/rfc.txt).

It is compiled from [rfc.raw.txt](https://github.com/edev/cs594-term-project/blob/master/rfc.raw.txt) using a simple table-of-contents generator written for this project, located at [util/toc](https://github.com/edev/cs594-term-project/blob/master/util/toc).

## Server

The server can be invoked through the [server](https://github.com/edev/cs594-term-project/blob/master/server) command-line application. The server implementation is located at [lib/server.rb](https://github.com/edev/cs594-term-project/blob/master/lib/server.rb). Invocations:

```
./server
./server PORT
```

## Client

The client can be invoked through the [client](https://github.com/edev/cs594-term-project/blob/master/client) command-line application. The client implementation is located at [lib/client.rb](https://github.com/edev/cs594-term-project/blob/master/lib/client.rb). Invocations:

```
./client HOST
./client HOST PORT
```

## Copyright

Copyright 2019 Dylan Laufenberg. All rights reserved.

Students in particular are expressly prohibited from using this work in their own work for classes. If you know Ruby well enough to defend this project as your own, then it shouldn't be much trouble to write it yourself.
