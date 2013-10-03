# http://zguide.zeromq.org/py:lpserver
require 'ffi-rzmq'
require 'logger'

module LazyPirate
  class Server
    attr_accessor :max_cycles, :server_port, :logger
    def initialize(
      logger:     Logger.new(STDOUT), 
      max_cycles: 3,
      server_port: 5555)

      @logger      = logger
      @max_cycles  = max_cycles
      @server_port = server_port
    end

    def connect
      @context = ZMQ::Context.new(1)
      @server_socket  = @context.socket(ZMQ::REP)
      @server_socket.bind("tcp://*:#{server_port}") 
    end

    def run
      connect
      cycles = 0

      loop do
        @server_socket.recv_string(message="")
        cycles = cycles + 1
        if (cycles > max_cycles) && (rand(3) == 0)  
          logger.info "I: simulating a crash"
          break
        else
          if (cycles > max_cycles) && (rand(3) == 0) 
            logger.info "I: simulating CPU overload"
            sleep 2
          end
          logger.info "I: normal request - #{message}"
          sleep 1 # simulate heavy work
          @server_socket.send_string message
        end  
      end
    end
    ##--
  end
end

lps = LazyPirate::Server.new
lps.run
