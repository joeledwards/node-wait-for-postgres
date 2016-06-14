Q = require 'q'
pg = require 'pg'
program = require 'commander'
durations = require 'durations'

getConnection = (uri, connectTimeout) ->
  d = Q.defer()
  client = new pg.Client uri
  client.connect (error) -> if error? then d.reject error else d.resolve client
  Q.timeout d.promise, connectTimeout, new Error('connection timeout')
  .then (client) -> client
  .catch (error) ->
    client.end()
    throw error

# Wait for Postgres to become available
waitForPostgres = (config) ->
  deferred = Q.defer()
  uri = "postgres://#{config.username}:#{config.password}@#{config.host}:#{config.port}/#{config.database}"
  console.log "URI: #{uri}"

  # timeouts in milliseconds
  connectTimeout = config.connectTimeout
  totalTimeout = config.totalTimeout

  quiet = config.quiet

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

      if config.query?
        queryString = config.query
        console.log "Connected. Running test query: '#{queryString}'"
        client.query queryString, (error, result) ->
          console.log "Query done."
          client.end()
          if (error)
            console.log "[#{error}] Attempt #{attempts} query failure. Time elapsed: #{watch}" if not quiet
            if watch.duration().millis() > totalTimeout
              console.log "Postgres test query failed." if not quiet
              deferred.resolve 1
            else
              totalRemaining = Math.min connectTimeout, Math.max(0, totalTimeout - watch.duration().millis())
              connectDelay = Math.min totalRemaining, Math.max(0, connectTimeout - connectWatch.duration().millis())
              setTimeout testConnection, connectDelay
          else
            watch.stop()
            console.log "Query succeeded after #{attempts} attempt(s) over #{watch}"
            deferred.resolve 0
      else
        watch.stop()
        console.log "Connected after #{attempts} attempt(s) over #{watch}"
        client.end()
        deferred.resolve 0

    # Handle connection failure
    .catch (error) ->
      connectWatch.stop()
      console.log "[#{error}] Attempt #{attempts} timed out. Time elapsed: #{watch}" if not quiet
      if watch.duration().millis() > totalTimeout
        console.log "Could not connect to Postgres." if not quiet
        deferred.resolve 1
      else
        totalRemaining = Math.min connectTimeout, Math.max(0, totalTimeout - watch.duration().millis())
        connectDelay = Math.min totalRemaining, Math.max(0, connectTimeout - connectWatch.duration().millis())
        setTimeout testConnection, connectDelay

  testConnection()

  deferred.promise

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

  config =
    host: program.host ? 'localhost'
    port: program.port ? 5432
    username: program.username ? 'postgres'
    password: program.password ? ''
    database: program.database ? 'postgres'
    connectTimeout: program.connectTimeout ? 250
    totalTimeout: program.totalTimeout ? 15000
    query: program.query ? null
    quiet: program.quiet ? false

  waitForPostgres(config)
  .then (code) ->
    process.exit code

# Module
module.exports =
  await: waitForPostgres
  run: runScript

# If run directly
if require.main == module
  runScript()

