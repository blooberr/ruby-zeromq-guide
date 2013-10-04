# ported from python: http://zguide.zeromq.org/py:spworker

require 'ffi-rzmq'
require 'securerandom'
require 'logger'

module SimplePirate
  class Worker
    attr_accessor :server_port, :logger, :identity
    LRU_READY = "\x01"
    def initialize(
      logger:      Logger.new(STDOUT),
      server_port: 5556)

      @logger      = logger
      @identity    = SecureRandom.hex
      @server_port = server_port 
    end

    def connect
      @context        = ZMQ::Context.new(1)
      @worker_socket  = @context.socket(ZMQ::REQ)
      @worker_socket.setsockopt(ZMQ::IDENTITY, @identity)
      @worker_socket.connect("tcp://localhost:#{server_port}")

      logger.info "I: #{@identity} worker is ready."
      @worker_socket.send_string(LRU_READY)
    end

    def run
      connect
      cycles = 0
      loop do
        message = []
        @worker_socket.recv_strings(message)

        cycles = cycles + 1
        if (cycles > 3) && (rand(5) == 0)
          logger.info "I: #{identity} simulating a crash."
          break
        elsif (cycles > 3) && (rand(5) == 0)
          logger.info "I: #{identity} simulating server overload"
          sleep 3
        end
        logger.info "I: #{identity} normal reply"
        sleep 1

        logger.info "Sending message - #{message}"              
        @worker_socket.send_strings(message)
      end       
    end
    ##---
  end
end

spw = SimplePirate::Worker.new
spw.run

