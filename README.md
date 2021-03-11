# Ruby Coding Challenge - Memcached server
Memcached is a high performance multithreaded event-based key/value cache store intended to be used in a distributed system.
See: [https://memcached.org/about](https://memcached.org/about)

*[Task:](https://github.com/moove-it/coding-challenges/blob/master/ruby.md)*
Implement a Memcached server (TCP/IP socket) that complies with the specified protocol.
The server must listen for new connections on a given TCP port. The implementation must accept connections and commands from any Memcached client and respond appropriately.

## Installation

 1. Install [Ruby](https://www.ruby-lang.org/en/downloads/)  (skip if already installed)
 2. Run  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`$ ruby -v` 
	to check version
		*Build tested with*mdl r  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`ruby 2.7.2p137 (2020-10-01 revision 5445e04352) [x64-mingw32]`  
3. Download or clone repository.

## Usage
*Optional setting before running the server:*
Head over to [.lib/memcached_server](./lib/memcached_server.rb) and set

    @debug = [true || false]
 *inside "initialize" method* for enabling or disabling server-side logging. 

### Run
1. Cd into directory and run
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;	 `$ ruby .\lib\memcached_server.rb`  
2. Server should be up and running on port 11211! 
	Check logs for:  `Listening on localhost:11211`
3. Connect with a client to the server and start issuing commands*

*Full [protocol](https://github.com/memcached/memcached/blob/master/doc/protocol.txt) of commands and responses

## Testing

TODO

