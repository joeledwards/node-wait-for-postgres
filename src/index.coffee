P = require 'bluebird'
pg = require 'pg'
program = require 'commander'
durations = require 'durations'

config = require './config'

getConnection = (uri, connectTimeout) ->
  new P (resolve, reject) ->
    client = new pg.Client uri
    client.connect (error) ->
      if error? then reject error else resolve client
  .timeout connectTimeout
  .catch (error) ->
    client.end()
    throw error

# Wait for Postgres to become available
waitForPostgres = (partialConfig) ->
  config.validate partialConfig
  .then (cfg) ->
    new P (resolve) ->
      {
        username, password, host, port, database,
        connectTimeout, totalTimeout, quiet, query
      } = cfg

      uri = "postgres://#{username}:#{password}@#{host}:#{port}/#{database}"
      console.log "URI: #{uri}"

      watch = durations.stopwatch().start()
      connectWatch = durations.stopwatch()

      attempts = 0

      # Recursive connection test function
      testConnection = () ->
        attempts += 1
        connectWatch.reset().start()

        # Establish a client connection
        getConnection uri, connectTimeout

        # Run the test query with the connected client
        .then (client) ->
          connectWatch.stop()

          # If a query was supplied, it must succeed before reporting success
          if query?
            console.log "Connected. Running test query: '#{query}'"
            client.query query, (error, result) ->
              console.log "Query done."
              client.end()
              if (error)
                console.log "[#{error}] Attempt #{attempts} query failure. Time elapsed: #{watch}" if not quiet
                if watch.duration().millis() > totalTimeout
                  console.log "Postgres test query failed." if not quiet
                  resolve 1
                else
                  totalRemaining = Math.min connectTimeout, Math.max(0, totalTimeout - watch.duration().millis())
                  connectDelay = Math.min totalRemaining, Math.max(0, connectTimeout - connectWatch.duration().millis())
                  setTimeout testConnection, connectDelay
              else
                watch.stop()
                console.log "Query succeeded after #{attempts} attempt(s) over #{watch}"
                resolve 0
          # If a query was not supplied, report success
          else
            watch.stop()
            console.log "Connected after #{attempts} attempt(s) over #{watch}"
            client.end()
            resolve 0

        # Handle connection failure
        .catch (error) ->
          connectWatch.stop()
          console.log "[#{error}] Attempt #{attempts} timed out. Time elapsed: #{watch}" if not quiet
          if watch.duration().millis() > totalTimeout
            console.log "Could not connect to Postgres." if not quiet
            resolve 1
          else
            totalRemaining = Math.min connectTimeout, Math.max(0, totalTimeout - watch.duration().millis())
            connectDelay = Math.min totalRemaining, Math.max(0, connectTimeout - connectWatch.duration().millis())
            setTimeout testConnection, connectDelay

      # First attempt
      testConnection()

# Script was run directly
runScript = () ->
  program
    .option '-D, --database <database>', 'Postgres database name (default is postgres)'
    .option '-h, --host <host>', 'Postgres hostname (default is localhost)'
    .option '-p, --port <port>', 'Postgres port (default is 5432)', parseInt
    .option '-P, --password <password>', 'Postgres user password (default is empty)'
    .option '-q, --quiet', 'Silence non-error output (default is false)'
    .option '-Q, --query <query_string>', 'Custom query to confirm database state'
    .option '-t, --connect-timeout <connect-timeout>', 'Individual connection attempt timeout (default is 250)', parseInt
    .option '-T, --total-timeout <total-timeout>', 'Total timeout across all connect attempts (dfault is 15000)', parseInt
    .option '-u, --username <username>', 'Posgres user name (default is postgres)'
    .parse(process.argv)

  partialConfig =
    host: program.host
    port: program.port
    username: program.username
    password: program.password
    database: program.database
    connectTimeout: program.connectTimeout
    totalTimeout: program.totalTimeout
    query: program.query
    quiet: program.quiet

  waitForPostgres(partialConfig)
  .then (code) ->
    process.exit code

# Module
module.exports =
  await: waitForPostgres
  run: runScript

# If run directly
if require.main == module
  runScript()

