# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"
require "./../utils"

include Sushi::Core::Models
include Sushi::Core
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe BlockchainInfo do
  describe "default non implemented methods" do
    it "should perform #setup" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        transaction_creator = BlockchainInfo.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.setup.should be_nil
      end
    end
    it "should perform #transaction_actions" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        transaction_creator = BlockchainInfo.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.transaction_actions.size.should eq(0)
      end
    end
    it "should perform #transaction_related?" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        transaction_creator = BlockchainInfo.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.transaction_related?("action").should be_false
      end
    end
    it "should perform #valid_transaction?" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_creator = BlockchainInfo.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.valid_transaction?(chain.last.transactions.first, chain.last.transactions).should be_true
      end
    end
    it "should perform #record" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_creator = BlockchainInfo.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.record(chain).should be_nil
      end
    end
    it "should perform #clear" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(2).chain
        transaction_creator = BlockchainInfo.new(blockchain_node(transaction_factory.sender_wallet))
        transaction_creator.clear.should be_nil
      end
    end
  end

  describe "#define_rpc?" do
    describe "#blockchain_size" do
      it "should return the blockchain size for the current node" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "blockchain_size"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq(%{{"size":11}})
          end
        end
      end
    end

    describe "#blockchain" do
      it "should return the full blockchain including headers" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "blockchain", header: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq(blockchain.chain.to_json)
          end
        end
      end

      it "should return the blockchain headers only" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "blockchain", header: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq(blockchain.headers.to_json)
          end
        end
      end
    end

    describe "#transactions" do
      it "should return transactions for the specified block index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transactions", index: 1}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq(blockchain.chain[1].transactions.to_json)
          end
        end
      end

      it "should return transactions for the specified address" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          address = chain.last.transactions.last.recipients.last["address"]
          payload = {call: "transactions", address: address}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            transactions_for_the_address = chain.flat_map { |blk| blk.transactions }.select { |txn| txn.recipients.map { |r| r["address"] }.includes?(address) }.to_json
            result.should eq(transactions_for_the_address)
          end
        end
      end

      it "should raise an error: invalid index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "transactions", index: 99}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "invalid index 99 (Blockchain size is 11)") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), {} of String => String)
          end
        end
      end
    end
    
    describe "#block" do
      it "should return the block specified by the supplied block index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", index: 2, header: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq(chain[1].to_json)
          end
        end
      end

      it "should return the block header specified by the supplied block index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", index: 2, header: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            result.should eq(blockchain.headers[2].to_json)
          end
        end
      end

      it "should return the block specified by the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          transaction_id = chain.last.transactions.last.id
          payload = {call: "block", transaction_id: transaction_id, header: false}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            expected_block = chain.select { |blk| blk.transactions.map { |txn| txn.id }.includes?(transaction_id) }.first.to_json
            result.should eq(expected_block)
          end
        end
      end

      it "should return the block header specified by the supplied transaction id" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          transaction_id = chain.last.transactions.last.id
          payload = {call: "block", transaction_id: transaction_id, header: true}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(rpc, json) do |result|
            block_index = chain.select { |blk| blk.transactions.map { |txn| txn.id }.includes?(transaction_id) }.first.index
            expected_block_header = blockchain.headers[block_index].to_json
            result.should eq(expected_block_header)
          end
        end
      end

      it "should raise a error: invalid index" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", index: 99, header: false}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "invalid index 99 (Blockchain size is 11)") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), {} of String => String)
          end
        end
      end

      it "should raise an error: failed to find a block for the transaction" do
        with_node do |sender_wallet, recipient_wallet, chain, blockchain, rpc|
          payload = {call: "block", transaction_id: "invalid-transaction-id", header: false}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, "failed to find a block for the transaction invalid-transaction-id") do
            rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), {} of String => String)
          end
        end
      end
    end
  end
  STDERR.puts "< dApps::BlockChainInfo"
end
