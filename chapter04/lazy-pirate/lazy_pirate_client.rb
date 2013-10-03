# translated from http://zguide.zeromq.org/py:lpclient
require 'ffi-rzmq'
require 'logger'

module LazyPirate
  class Client
    attr_accessor :logger, :retries, :server_port, :timeout
    def initialize(
      logger:      Logger.new(STDOUT),
      retries:     3,
      server_port: 5555,
      timeout:     5 * 1000) # in milliseconds

      @logger      = logger
      @retries     = retries
      @server_port = server_port
      @timeout     = timeout

      @context = ZMQ::Context.new(1)
      @poller = ZMQ::Poller.new
      reconnect
    end

    def reconnect
      if @client_socket
        @poller.deregister @client_socket, ZMQ::POLLIN
        @client_socket.close
        logger.info "Reconnecting ... "
      end

      @client_socket = @context.socket(ZMQ::REQ)
      @client_socket.setsockopt(ZMQ::LINGER, 0)
      @client_socket.connect("tcp://localhost:#{@server_port}")
      @poller.register @client_socket, ZMQ::POLLIN
    end

    def send
      retries.times do |tries|
        message = "message - ##{tries}"
        send_status = @client_socket.send_string(message)
        rc = @poller.poll(@timeout)
        if rc > 0
          @poller.readables.each do |socket|
            socket.recv_string(m="")
            puts "I: Server replied OK- #{m.inspect}"
          end
          return
        else
          reconnect
        end
        logger.info "W: no response from server, retry ##{tries}"
      end
      raise "E: server seems to be offline, abandoning!"
    end

    def run
      loop do
        send
      end
    end
  
    ##---
  end
end

lpc = LazyPirate::Client.new
lpc.run


