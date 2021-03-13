# Ruby Coding Challenge - Memcached server
Memcached is a high performance multithreaded event-based key/value cache store intended to be used in a distributed system.
See: [https://memcached.org/about](https://memcached.org/about)

*[Task:](https://github.com/moove-it/coding-challenges/blob/master/ruby.md)*
Implement a Memcached server (TCP/IP socket) that complies with the specified protocol.
The server must listen for new connections on a given TCP port. The implementation must accept connections and commands from any Memcached client and respond appropriately.

## Installation

 1. Install [Ruby](https://www.ruby-lang.org/en/downloads/)  (skip if already installed)
 2. Run<br />
`$ ruby -v`  to check version 
<br/>*Build tested with*
<br/>`ruby 2.7.2p137 (2020-10-01 revision 5445e04352) [x64-mingw32]`  
3. Download or clone repository.

## Usage
### Run server
1. Cd into directory

2. Run either<br/>
 `$ ruby .\start.rb` for silent server<br/>
or<br/>
 `$ ruby .\start_debug.rb` for server with console logging  

2. Server should be up and running on **port 11211**! 

3. Connect with a *client* to the server and start issuing commands*
<br/>

*[Full protocol](https://github.com/memcached/memcached/blob/master/doc/protocol.txt) and [relevant protocol](./protocol) of commands and responses

#### Clients

Various clients can be used to connect to the server. For example:

- Project's included [client](./lib/memcached_client) (run with `$ ruby .\client_start.rb`)
- [PuTTy](https://www.putty.org/)
- Windows' Telnet

And any other that supports **TCP**.
The server currently supports multiple concurrent clients.

**Usage:** Connect to `127.0.0.1:11211` and issue commands

## Supported Commands
### Retrieval
 ` $ get <key> [<key ... <key>]`
<br/> `$ gets <key> [<key ... <key>]`

### Storage

   ` $ <command name> <key> <flags> <exptime> <bytes> [noreply]`
   
Where  &nbsp; `<command name>` &nbsp; is one of:
- set
- add
- replace
- append
- prepend

Also supports:

  ` $ <cas> <key> <flags> <exptime> <bytes> <cas_unique> [noreply]`

Read protocol for more information on commands and arguments
### Other
` $ close`

Closes the connection to the server
## Testing

### Rspec

Testing implemented via Rspec gem

##### Usage

In root directory

1. Run
 `$ gem install rspec`

2. Run
 `$ rspec`


Tests should automatically run.

### JMeter

For load tests, JMeter was used.

##### Usage

1. Install [JMeter](https://jmeter.apache.org/download_jmeter.cgi)

2. In project's root directory, run:
 `$ ruby .\start.rb` for silent server (more performant as it does not output logs)

3. Open JMeter, pick a test from *./jmeter/*  and run it

500 threads ran without any problems. Some connection losses occurred on 2500 and 5000 threads.