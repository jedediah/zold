# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'minitest/autorun'
require_relative '../test__helper'
require_relative '../fake_home'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/pay'

# PAY test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestPay < Minitest::Test
  def test_sends_from_wallet_to_wallet
    FakeHome.new.run do |home|
      source = home.create_wallet
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(wallets: home.wallets, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'For the car'
        ]
      )
      assert_equal(amount * -1, source.balance)
    end
  end

  def test_sends_from_root_wallet
    FakeHome.new.run do |home|
      source = home.create_wallet(Zold::Id::ROOT)
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      Zold::Pay.new(wallets: home.wallets, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'For the car'
        ]
      )
      assert_equal(amount * -1, source.balance)
    end
  end

  def test_sends_from_normal_wallet
    FakeHome.new.run do |home|
      source = home.create_wallet
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      source.add(
        Zold::Txn.new(
          1, Time.now, amount,
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      Zold::Pay.new(wallets: home.wallets, remotes: home.remotes, log: test_log).run(
        [
          'pay', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'here is the refund'
        ]
      )
      assert_equal(Zold::Amount::ZERO, source.balance)
    end
  end

  def test_notifies_about_tax_status
    FakeHome.new.run do |home|
      source = home.create_wallet
      target = home.create_wallet
      amount = Zold::Amount.new(zld: 14.95)
      accumulating_log = test_log.dup
      class << accumulating_log
        attr_accessor :info_messages

        def info(message)
          (@info_messages ||= []) << message
        end
      end
      Zold::Pay.new(wallets: home.wallets, remotes: home.remotes, log: accumulating_log).run(
        [
          'pay', '--force', '--private-key=fixtures/id_rsa',
          source.id.to_s, target.id.to_s, amount.to_zld, 'For the car'
        ]
      )
      assert_equal accumulating_log.info_messages.grep(/^The tax debt/).size, 1,
        'No info_messages notified user of tax debt'
    end
  end
end
