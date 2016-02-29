# Greenplum Database (GPDB) 4.3.7.1 "Single Node" Dockerized (for testing purposes only)

Created in the persuit of an easily recreated test environment for a complicated application, which needs to communicate with a GPDB instance while running tests.

So, I jammed it into Docker, but this isn't something you'd want to use in a production
application.  But it seems to work for testing where you just want something that tests 
can execute against.

This is on Docker Hub here: https://hub.docker.com/r/kevinmtrowbridge/greenplumdb_singlenode/


## Running it

    docker run -i -p 5432:5432 -t kevinmtrowbridge/greenplumdb_singlenode

Proof -- login with psql:

    psql -h <docker machine ip / localhost> -p 5432 -U gpadmin template1


## Docker build

Download greenplum-db-appliance-4.3.7.1-build-1-RHEL5-x86_64.bin from Pivotal Network
https://network.pivotal.io/products/pivotal-gpdb#/releases/1377  
(This was working on 1/28/2016) ... and just place it in the repo root.

Then:

    docker build -t greenplumdb_singlenode .


## Discussion

I don't deeply understand GPDB but, in my understanding it's a distributed database (think Hadoop) which would involve a "cluster" of servers ... you submit a super heavy Postgres query to a master instance, which then sends it out to hundreds or thousands of child nodes, which run queries in parallel and then send the results back to the master.

So, it seems like Docker could be useful for this, if you could figure out how to keep the data on persistible volumes ... 

What this is, the "singlenode" mode -- doesn't accomplish any of the heavy parallel data processing stuff, so really, it's only useful for testing, or as starting point to outline the problems GPDB currently has with Docker and what might be involved with getting GPDB to run on Docker in a non "singlenode" mode.

Please see the Dockerfile for comments regarding the problems I had installing it on Docker and
how I hacked around them ...
