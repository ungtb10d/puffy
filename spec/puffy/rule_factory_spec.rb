# frozen_string_literal: true

require 'puffy'

module Puffy
  RSpec.describe RuleFactory do
    it 'empty rules produce no rule' do
      expect(Rule).not_to receive(:new)

      expect(subject.build).to eq([])
    end

    it 'iterates over array values' do
      expect(Rule).to receive(:new).and_call_original

      result = subject.build(proto: :tcp)
      expect(result.count).to eq(1)
      expect(result.first.proto).to eq(:tcp)

      expect(Rule).to receive(:new).twice.and_call_original

      result = subject.build(proto: %i[tcp udp])
      expect(result.count).to eq(2)
      expect(result[0].proto).to eq(:tcp)
      expect(result[1].proto).to eq(:udp)
    end

    it 'passes addresses and networks' do
      result = subject.build(to: [{ host: IPAddr.new('192.0.2.1') }])

      expect(result.count).to eq(1)
      expect(result[0].to[:host]).to eq(IPAddr.new('192.0.2.1'))

      result = subject.build(to: [{ host: IPAddr.new('192.0.2.0/24') }])

      expect(result.count).to eq(1)
      expect(result[0].to[:host]).to eq(IPAddr.new('192.0.2.0/24'))
    end

    it 'resolves hostnames' do
      expect(Rule).to receive(:new).twice.and_call_original
      expect(Puffy::Resolver.instance).to receive(:resolv).with('example.com').and_return([IPAddr.new('2001:DB8::1'), IPAddr.new('192.0.2.1')])

      result = subject.build(to: [{ host: 'example.com' }])

      expect(result.count).to eq(2)
      expect(result[0].to[:host]).to eq(IPAddr.new('2001:DB8::1'))
      expect(result[1].to[:host]).to eq(IPAddr.new('192.0.2.1'))
    end

    it 'accepts service names' do
      expect(Rule).to receive(:new).twice.and_call_original

      result = subject.build(proto: :tcp, to: [{ port: %w[http https] }])

      expect(result.count).to eq(2)
      expect(result[0].proto).to eq(:tcp)
      expect(result[0].to[:port]).to eq(80)
      expect(result[1].proto).to eq(:tcp)
      expect(result[1].to[:port]).to eq(443)

      expect { subject.build(to: [{ port: 'invalid' }]) }.to raise_error('unknown service "invalid"')
    end

    it 'accepts service alt-names' do
      expect(Rule).to receive(:new).exactly(3).times.and_call_original

      result = subject.build(proto: :tcp, to: [{ port: %w[auth tap ident] }])

      expect(result.count).to eq(3)
      expect(result[0].proto).to eq(:tcp)
      expect(result[0].to[:port]).to eq(113)
      expect(result[1].proto).to eq(:tcp)
      expect(result[1].to[:port]).to eq(113)
      expect(result[2].proto).to eq(:tcp)
      expect(result[2].to[:port]).to eq(113)
    end

    it 'does not mix IPv4 and IPv6' do
      expect(Puffy::Resolver.instance).to receive(:resolv).with('example.net').and_return([IPAddr.new('2001:DB8::FFFF:FFFF:FFFF'), IPAddr.new('198.51.100.1')])
      expect(Puffy::Resolver.instance).to receive(:resolv).with('example.com').and_return([IPAddr.new('2001:DB8::1'), IPAddr.new('192.0.2.1')])

      expect(Rule).to receive(:new).exactly(4).times.and_call_original

      result = subject.build(from: [{ host: 'example.net' }], to: [{ host: 'example.com' }])

      expect(result.count).to eq(2)
      expect(result[0].from[:host]).to eq(IPAddr.new('2001:DB8::FFFF:FFFF:FFFF'))
      expect(result[0].to[:host]).to eq(IPAddr.new('2001:DB8::1'))
      expect(result[1].from[:host]).to eq(IPAddr.new('198.51.100.1'))
      expect(result[1].to[:host]).to eq(IPAddr.new('192.0.2.1'))
    end

    it 'filters address family' do
      result = subject.build(af: :inet, proto: :icmp)
      expect(result.count).to eq(1)

      result = subject.build(af: :inet6, proto: :icmpv6)
      expect(result.count).to eq(1)
    end

    it 'limits scope to IP version' do
      result = []

      subject.ipv4 do
        result = subject.build(to: [{ host: 'example.com' }])
      end
      expect(result.count).to eq(1)
      expect(result[0].to[:host]).to eq(IPAddr.new('93.184.216.34'))

      subject.ipv6 do
        result = subject.build(to: [{ host: 'example.com' }])
      end
      expect(result.count).to eq(1)
      expect(result[0].to[:host]).to eq(IPAddr.new('2606:2800:220:1:248:1893:25c8:1946'))
    end
  end
end
