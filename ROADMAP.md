# Roadmap

The roadmap is a high level overview of work we would like to see implemented. For more details and discussion of new features, improvements or bugs, please see the [issue list](https://github.com/apache/openserverless/issues) in GitHub. 

The order of the items does not pretend to to establish the project priorities.

* OpenServerless Operator
    * Improvement: migrate to newer OpenWhisk 2.0.0 (controller+secheduler+invoker)
    * New: Integrate Apache Apisix
    * New: Implements admission webhooks for wsk and wsku resources
    * New: Implements a generic S3 Api aware plugin for User and Bucket creations
    * Improvement: Migrate to newer version of MINIO server
    * Improvement: Migrate to newer version os Postgres SQL
    * Improvement: Update to latest kopf version and latest Python version
    * Improvement: Deploy default nuvolaris namespace as a normal wsku resources
    * Improvement: Handle CouchDb init task as Operator managed task
    * Improvement: Use base images with smaller size for fast loading
    * New: Integrate Argo Events and implements system action to support deployment of argo events resources
    * New: Implement a new customizable Job to perform CouchDb maintenance task (database compaction, activations cleanup)
    * Refactoring: Adopt a plugin based implemenation
* OpenServerless CLI (aka ops)
    * TODO 
* OpenServerless Tasks
    * New: implemens task to schedule actions using argo events supporting actions
* OpenServerless runtimes
    * Improvement: call to runtime at / should implement /run behavior as OpenWhisk web actions.