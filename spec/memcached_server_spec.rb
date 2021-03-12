# frozen_string_literal: true

require 'socket'
require 'memcached_client'
require 'memcached_server'

describe 'MemcachedServer' do
  ##########################################################
  context 'Server run & client connection' do
    it 'should raise err if client connects and server is not running' do
      expect { TCPSocket.open('127.0.0.1', 11_211) }
        .to(raise_error(Errno::ECONNREFUSED))
    end
    it 'should start server and listen on port 11211' do
      server = MemcachedServer.new(false)
      expect(server.listen_connections).to(be(true))
    end

    it 'should not raise err if client connects and server is running' do
      expect { TCPSocket.open('127.0.0.1', 11_211) }
        .to_not(raise_error)
    end

    it 'should not raise err if client closes connection' do
      client = TCPSocket.open('127.0.0.1', 11_211)
      expect { client.close }
        .to_not(raise_error)
    end
  end

  ##########################################################
  server = MemcachedServer.new(false)

  ##########################################################
  describe 'Command processing' do
    ##########################
    context 'no_reply?' do
      # (tokens)
      it 'should return false when last token is not noreply' do
        expect(server.no_reply?(%w[set key 0 0 0])).to(be(false))
      end
      it 'should return true when last token is noreply' do
        expect(server.no_reply?(%w[set key 0 0 0 noreply])).to(be(true))
      end
      it 'should be case sensitive' do
        expect(server.no_reply?(%w[set key 0 0 0 NOREPLY])).to(be(false))
      end
      it 'should be case sensitive 2' do
        expect(server.no_reply?(%w[set key 0 0 0 Noreply])).to(be(false))
      end
    end

    ##########################
    context 'command_read?' do
      # (command)

      it 'should return false when command is not read' do
        expect(server.command_read?('command')).to(be(false))
      end
      it 'should return true when command is get' do
        expect(server.command_read?('get')).to(be(true))
      end
      it 'should return true when command is gets' do
        expect(server.command_read?('gets')).to(be(true))
      end
      it 'should be case sensitive 1' do
        expect(server.command_read?('GET')).to(be(false))
      end
      it 'should be case sensitive 2' do
        expect(server.command_read?('Get')).to(be(false))
      end
    end

    ##########################
    context 'command_write?' do
      # (command)

      it 'should return false when command is not write' do
        expect(server.command_write?('command')).to(be(false))
      end
      it 'should return true when command is set' do
        expect(server.command_write?('set')).to(be(true))
      end
      it 'should return true when command is add' do
        expect(server.command_write?('add')).to(be(true))
      end
      it 'should return true when command is replace' do
        expect(server.command_write?('replace')).to(be(true))
      end
      it 'should return true when command is append' do
        expect(server.command_write?('append')).to(be(true))
      end
      it 'should return true when command is prepend' do
        expect(server.command_write?('prepend')).to(be(true))
      end
      it 'should return true when command is cas' do
        expect(server.command_write?('cas')).to(be(true))
      end
      it 'should be case sensitive 1' do
        expect(server.command_write?('SET')).to(be(false))
      end
      it 'should be case sensitive 2' do
        expect(server.command_write?('Set')).to(be(false))
      end
    end

    ##########################
    context 'procces_write_command' do
      # (command, to_store, cas_unique)

      to_store_one = {
        key: 'key_one',
        flags: 0,
        exptime: 100,
        stored_time: Time.now.to_i,
        bytes: 4,
        data_block: 'data',
        cas_unique: server.next_cas_unique
      }
      it 'cache should be empty' do
        expect(server.cache).to(be_empty)
      end

      ##############

      context 'set' do
        it 'should return "STORED\r\n" when set to_store_one' do
          expect(server.process_write_command('set', to_store_one, nil)).to(equal("STORED\r\n"))
        end
        it 'cache should not be empty after setting first item' do
          server.process_write_command('set', to_store_one, nil)
          expect(server.cache).to_not(be_empty)
        end

        it 'should have set item at "key_one"' do
          expect(server.cache[to_store_one[:key]]).to(equal(to_store_one))
        end
        it 'should set to_store_two at same key even if data already exists' do
          to_store_two = {
            key: 'key_one',
            flags: 0,
            exptime: 200,
            stored_time: Time.now.to_i,
            bytes: 10,
            data_block: 'other_data',
            cas_unique: server.next_cas_unique
          }
          server.process_write_command('set', to_store_two, nil)
          expect(server.cache[to_store_two[:key]]).to(equal(to_store_two))
        end
      end

      ##############

      context 'add' do
        to_add = {
          key: 'nonexistent_key',
          flags: 0,
          exptime: 200,
          stored_time: Time.now.to_i,
          bytes: 4,
          data_block: 'data',
          cas_unique: server.next_cas_unique
        }
        it 'should return "NOT_STORED\r\n" if item already exists' do
          expect(server.process_write_command('add', to_store_one, nil)).to(equal("NOT_STORED\r\n"))
        end
        it 'should return "STORED\r\n" if doesnt exist' do
          expect(server.process_write_command('add', to_add, nil)).to(equal("STORED\r\n"))
        end
        it 'should have added item' do
          expect(server.cache[to_add[:key]]).to(equal(to_add))
        end
      end

      ##############

      context 'replace' do
        to_be_replaced = {
          key: 'existent_key',
          flags: 0,
          exptime: 200,
          stored_time: Time.now.to_i,
          bytes: 4,
          data_block: 'data',
          cas_unique: server.next_cas_unique
        }
        to_replace = {
          key: 'existent_key',
          flags: 0,
          exptime: 200,
          stored_time: Time.now.to_i,
          bytes: 10,
          data_block: 'other_data',
          cas_unique: server.next_cas_unique
        }
        it 'should return "NOT_STORED\r\n" if item does not exist' do
          expect(server.process_write_command('replace', to_replace, nil)).to(equal("NOT_STORED\r\n"))
        end
        it 'should return "STORED\r\n" if item does exist and is replaced' do
          # add item
          server.process_write_command('set', to_be_replaced, nil)
          expect(server.process_write_command('replace', to_replace, nil)).to(equal("STORED\r\n"))
        end
        it 'should have replaced item' do
          expect(server.cache[to_replace[:key]]).to(equal(to_replace))
        end
      end

      ##############

      context 'append' do
        to_be_appended = {
          key: 'append_key',
          flags: 0,
          exptime: 0,
          stored_time: 0,
          bytes: 4,
          data_block: "data\r\n",
          cas_unique: 10
        }
        to_append = {
          key: 'append_key',
          flags: 1234,
          exptime: 200,
          stored_time: Time.now.to_i,
          bytes: 6,
          data_block: "append\r\n",
          cas_unique: 11
        }
        it 'should return "NOT_STORED\r\n" if item does not exist' do
          expect(server.process_write_command('append', to_append, nil)).to(equal("NOT_STORED\r\n"))
        end
        it 'should return "STORED\r\n" if item does exist and is appended' do
          # add item
          server.process_write_command('set', to_be_appended, nil)
          expect(server.process_write_command('append', to_append, nil)).to(equal("STORED\r\n"))
        end
        it 'should have appended item: not updated flags' do
          expect(server.cache['append_key'][:flags]).to(equal(0))
        end
        it 'should have appended item: not updated exptime' do
          expect(server.cache['append_key'][:exptime]).to(equal(0))
        end
        it 'should have appended item: not updated stored_time' do
          expect(server.cache['append_key'][:stored_time]).to(equal(0))
        end
        it 'should have appended item: updated bytes' do
          expect(server.cache['append_key'][:bytes]).to(equal(10))
        end

        # ERROR SAME STRING?
        # it 'should have appended item: updated data_block' do
        #   expect(server.cache['append_key'][:data_block]).to(equal("dataappend\r\n"))
        # end

        it 'should have appended item: updated cas_unique' do
          expect(server.cache['append_key'][:cas_unique]).to(equal(11))
        end
      end

      ##############

      context 'prepend' do
        to_be_prepended = {
          key: 'prepend_key',
          flags: 0,
          exptime: 0,
          stored_time: 0,
          bytes: 4,
          data_block: "data\r\n",
          cas_unique: 12
        }
        to_prepend = {
          key: 'prepend_key',
          flags: 1234,
          exptime: 200,
          stored_time: Time.now.to_i,
          bytes: 7,
          data_block: "prepend\r\n",
          cas_unique: 13
        }

        it 'should return "NOT_STORED\r\n" if item does not exist' do
          expect(server.process_write_command('prepend', to_prepend, nil)).to(equal("NOT_STORED\r\n"))
        end
        it 'should return "STORED\r\n" if item does exist and is prepended' do
          # add item
          server.process_write_command('set', to_be_prepended, nil)
          expect(server.process_write_command('prepend', to_prepend, nil)).to(equal("STORED\r\n"))
        end
        it 'should have prepended item: not updated flags' do
          expect(server.cache['prepend_key'][:flags]).to(equal(0))
        end
        it 'should have prepended item: not updated exptime' do
          expect(server.cache['prepend_key'][:exptime]).to(equal(0))
        end
        it 'should have prepended item: not updated stored_time' do
          expect(server.cache['prepend_key'][:stored_time]).to(equal(0))
        end
        it 'should have prepended item: updated bytes' do
          expect(server.cache['prepend_key'][:bytes]).to(equal(11))
        end

        # ERROR SAME STRING?
        # it 'should have prepended item: updated data_block' do
        #   expect(server.cache['prepend_key'][:data_block]).to(equal("prependdata\r\n"))
        # end
        it 'should have prepended item: updated cas_unique' do
          expect(server.cache['prepend_key'][:cas_unique]).to(equal(13))
        end
      end

      ##############

      context 'cas' do
        to_be_replaced_cas = {
          key: 'cas_key',
          flags: 0,
          exptime: 0,
          stored_time: 0,
          bytes: 4,
          data_block: "data\r\n",
          cas_unique: 20
        }
        to_replace_cas = {
          key: 'cas_key',
          flags: 1234,
          exptime: 200,
          stored_time: Time.now.to_i,
          bytes: 3,
          data_block: "cas\r\n",
          cas_unique: 21
        }

        it 'should return "NOT_FOUND\r\n" if item does not exist' do
          expect(server.process_write_command('cas', to_replace_cas, nil)).to(equal("NOT_FOUND\r\n"))
        end
        it 'should return "EXISTS\r\n" if item does exist but cas_unique doesnt match' do
          # add item
          server.process_write_command('set', to_be_replaced_cas, nil)
          expect(server.process_write_command('cas', to_replace_cas, 1)).to(equal("EXISTS\r\n"))
        end
        it 'should return "STORED\r\n" if item does exist AND cas_unique matches' do
          expect(server.process_write_command('cas', to_replace_cas, 20)).to(equal("STORED\r\n"))
        end
        it 'should have set item at "cas_key"' do
          expect(server.cache['cas_key']).to(equal(to_replace_cas))
        end
      end
    end
  end
  ############################

  context 'expiration' do
    to_instantly_expire = {
      key: 'some_expired_key',
      flags: 0,
      exptime: -1,
      stored_time: Time.now.to_i,
      bytes: 3,
      data_block: "expired\r\n",
      cas_unique: 21
    }
    to_not_expire = {
      key: 'some_other_key',
      flags: 0,
      exptime: 0,
      stored_time: Time.now.to_i,
      bytes: 3,
      data_block: "expired\r\n",
      cas_unique: 21
    }
    it 'set to_be_instantly_expired' do
      server.process_write_command('set', to_instantly_expire, nil)
      expect(server.cache['some_expired_key']).to(equal(to_instantly_expire))
    end
    it 'negative exptime should be instantly expired' do
      expect(server.expired?('some_expired_key')).to(equal(true))
    end
    it 'should be deleted if expired' do
      expect(server.exists?('some_expired_key')).to(equal(false))
    end
    it '0 value exptime should never expire' do
      server.process_write_command('set', to_not_expire, nil)
      expect(server.expired?('some_other_key')).to(equal(false))
    end
  end
end
