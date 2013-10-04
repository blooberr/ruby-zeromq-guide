require 'ffi-rzmq'
require 'logger'

# run the lazy pirate client to connect to the simple pirate queue (broker)
module SimplePirate
  class Queue
    attr_accessor :fe_port, :be_port, :workers, :logger
    LRU_READY = "\x01"
    def initialize(
      fe_port: 5555,
      be_port: 5556,
      logger:  Logger.new(STDOUT))

      @fe_port = fe_port
      @be_port = be_port
      @logger  = logger
      @workers = []
    end

    def connect
      @context = ZMQ::Context.new(1)
      @fe_node = @context.socket(ZMQ::ROUTER)
      @be_node = @context.socket(ZMQ::ROUTER)

      @fe_node.bind("tcp://*:#{fe_port}")
      @be_node.bind("tcp://*:#{be_port}")

      @fe_poller = ZMQ::Poller.new
      @be_poller = ZMQ::Poller.new

      @fe_poller.register(@fe_node, ZMQ::POLLIN)
      @be_poller.register(@be_node, ZMQ::POLLIN)
    end

    def run
      connect
      loop do

        #if !workers.empty?
          rc = @fe_poller.poll(50)
          if rc > 0
            @fe_poller.readables.each do |socket|
              message = []
              socket.recv_strings message
              message.unshift ""
              
              # route to first available worker
              addr = workers.shift
              message.unshift addr
              logger.info "sending request to first available worker #{message}" 
              @be_node.send_strings message
            end
         end
        #end

        rc = @be_poller.poll(50)
        if rc > 0
          @be_poller.readables.each do |socket|
            message = [] # if you don't clear it here the array will keep growing
            socket.recv_strings(message)
            puts "be message - #{message}"   
            address = message.shift
            message.shift
            reply = message[0]

            # reply to client if its not a ready
            if reply != LRU_READY
              logger.info "reply to client on fe node!! -> #{message}"
              workers.unshift address
              @fe_node.send_strings message
            else
              workers << address
              logger.info "backend node #{address} connected."
            end
          end
        end

      end
    end
    ##--
  end
end

# ref: https://github.com/mattconnolly/zguide-rbczmq/blob/master/lbbroker2.rb

spq = SimplePirate::Queue.new
spq.run

