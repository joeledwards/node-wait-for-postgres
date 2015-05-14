Q = require 'q'
pg = require 'pg'
program = require 'commander'
durations = require 'durations'

# Wait for Postgres to become available
waitForPostgres = (config) ->
  deferred = Q.defer()
  uri = "postgres://#{config.username}:#{config.password}@#{config.host}:#{config.port}/#{config.database}"

  # timeouts in milliseconds
  connectTimeout = 250
  totalTimeout = 15000

  quiet = config.quiet

  watch = durations.stopwatch().start()
  connectWatch = durations.stopwatch()

  attempts = 0

  # Recursive connection test function
  testConnection = () ->
    attempts += 1
    connectWatch.reset().start()
    pg.connect uri, (error, client, done) ->
      connectWatch.stop()
      if error?
        console.log "[#{error}] Attempt #{attempts} timed out. Time elapsed: #{watch}" if not quiet
        if watch.duration().millis() > totalTimeout
          console.log "Could not connect to Postgres." if not quiet
          deferred.resolve 1
        else
          totalRemaining = Math.min connectTimeout, Math.max(0, totalTimeout - watch.duration().millis())
          connectDelay = Math.min totalRemaining, Math.max(0, connectTimeout - connectWatch.duration().millis())
          setTimeout testConnection, connectDelay
      else
        if config.query?
          console.log "Connected. Running test query."
          client.query config.query, (error, result) ->
            console.log "Query done."
            done()
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
              console.log "Query succeeded. #{attempts} attempts over #{watch}"
              deferred.resolve 0
        else
          watch.stop()
          console.log "Connected. #{attempts} attempts over #{watch}"
          done()
          deferred.resolve 0

  testConnection()

  deferred.promise

# Script was run directly
runScript = () ->
  program
    .option '-D, --database <db_name>', 'Postgres database (default is postgres)'
    .option '-h, --host <hostname>', 'Postgres host (default is localhost)'
    .option '-p, --port <port>', 'Postgres port (default is 5432)', parseInt
    .option '-P, --password <password>', 'Postgres user password (default is empty)'
    .option '-q, --quiet', 'Silence non-error output (default is false)'
    .option '-Q, --query', 'Custom query to confirm database state'
    .option '-t, --connect-timeout <milliseconds>', 'Individual connection attempt timeout (default is 250)', parseInt
    .option '-T, --total-timeout <milliseconds>', 'Total timeout across all connect attempts (dfault is 15000)', parseInt
    .option '-u, --username <username>', 'Posgres user name (default is postgres)'
    .parse(process.argv)

  config =
    host: program.host ? 'localhost'
    port: program.port ? 5432
    username: program.username ? 'postgres'
    password: program.password ? ''
    database: program.database ? 'postgres'
    query: program.query ? null
    quiet: program.quiet ? false

  waitForPostgres(config)
  .then (code) ->
    process.exit code

# Module
module.exports =
  await: waitForPostgres

# If run directly
if require.main == module
  runScript()

