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

include Sushi::Core
include Units::Utils
include Sushi::Core::Controllers
include Sushi::Core::Keys

describe RPCController do
  describe "#exec_internal_post" do
    describe "#create_unsigned_transaction" do
      it "should return the transaction as json when valid" do
        with_factory do |block_factory, transaction_factory|
          senders = [a_sender(transaction_factory.sender_wallet, 1000_i64)]
          recipients = [a_recipient(transaction_factory.recipient_wallet, 10_i64)]

          payload = {
            call:       "create_unsigned_transaction",
            action:     "send",
            senders:    senders,
            recipients: recipients,
            message:    "",
            token:      TOKEN_DEFAULT,
          }.to_json

          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            transaction = Transaction.from_json(result)
            transaction.action.should eq("send")
            transaction.prev_hash.should eq("0")
            transaction.message.should eq("")
            transaction.sign_r.should eq("0")
            transaction.sign_s.should eq("0")
            transaction.senders.should eq(senders)
            transaction.recipients.should eq(recipients)
          end
        end
      end
    end

    describe "#unpermitted_call" do
      it "should raise an error: Missing hash key call" do
        with_factory do |block_factory, transaction_factory|
          payload = {unknown: "unknown"}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, %{Missing hash key: "call"}) do
            block_factory.rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), {} of String => String)
          end
        end
      end

      it "should return a 403 when the rpc call is unknown" do
        with_factory do |block_factory, transaction_factory|
          payload = {call: "unknown"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json, 403) do |result|
            result.should eq("unpermitted call: unknown")
          end
        end
      end
    end
  end

  describe "#exec_internal_get" do
    it "should return an unpermitted call response" do
      with_factory do |block_factory, transaction_factory|
        payload = {call: "unknown"}.to_json
        json = JSON.parse(payload)

        with_rpc_exec_internal_get(block_factory.rpc, 403) do |result|
          result.should eq("unpermitted method: GET")
        end
      end
    end
  end

  STDERR.puts "< Node::RPCController"
end
