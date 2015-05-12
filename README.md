
Wait for Postgres
===========

Waits for a PostgreSQL connection to become available, optionally running
a custom query to determine if the connection is valid.

Installation
============

```bash
npm install --save wait-for-postgres
```

Usage
=====

Run as a module within another script:

```coffeescript
waitForPg = require 'wait-for-postgres'
config =
  username: user
  password: pass
  quiet: true
  query: 'SELECT 1'

waitForPg.wait(config)
```
      

Or run stand-alone

```bash
wait-for-postgres --username=user --password=pass --quiet
```

Building
============

cake build

