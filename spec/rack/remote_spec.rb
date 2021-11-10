# frozen_string_literal: true

require 'spec_helper'

describe Rack::Remote do
  include Rack::Test::Methods

  let(:inner_app) { ->(_) { [200, {'Content-Type' => 'text/plain'}, 'All good!'] } }
  let(:app) { described_class.new(inner_app) }
  let(:block) { ->(_, _, _) {} }

  after { described_class.clear }

  describe 'call' do
    before { described_class.register :factory_bot, &block }

    context 'with intercept call' do
      let(:request) { -> { post '/', {}, {'HTTP_X_RACK_REMOTE_CALL' => 'factory_bot'} } }

      it 'invokes registered call' do
        expect(block).to receive(:call)
        request.call
      end

      it 'does not delegate request to inner app' do
        expect(inner_app).not_to receive(:call)
        request.call
      end
    end

    context 'with non-rack-remote call' do
      let(:request) { -> { post '/' } }

      it 'delegates request to inner app' do
        expect(inner_app).to receive(:call).and_call_original
        request.call
      end
    end
  end

  describe 'class' do
    describe '#register' do
      it 'adds callback' do
        expect do
          described_class.register :factory_bot, &block
        end.to change { described_class.calls.size }.from(0).to(1)
      end

      it 'adds given callback' do
        described_class.register :factory_bot, &block
        expect(described_class.calls.values.first).to equal block
      end
    end

    describe '#add' do
      subject(:add_remote) { -> { described_class.add :users, url: 'http://users.example.org' } }

      it 'adds a remote' do
        expect { add_remote.call }.to change { described_class.remotes.size }.from(0).to(1)
      end

      it 'adds given remote' do
        add_remote.call
        expect(described_class.remotes[:users]).to eq url: 'http://users.example.org'
      end
    end

    describe '#invoke' do
      before do
        stub_request(:any, /users\.example\.org/).to_rack(app)

        described_class.register :factory_bot, &block
        described_class.add :users, url: 'http://users.example.org'
      end

      it 'invokes remote call' do
        expect(block).to receive(:call).with({'param1' => 'val1'}, kind_of(Hash), kind_of(Rack::Request)).and_return({id: 1})
        ret = described_class.invoke :users, :factory_bot, param1: 'val1'
        expect(ret).to eq({'id' => 1})
      end

      it 'invokes remote call (2)' do
        expect(block).to receive(:call).with({'param1' => ['val1', {'abc' => 'cde'}]}, kind_of(Hash), kind_of(Rack::Request)).and_return({id: 1})
        ret = described_class.invoke :users, :factory_bot, param1: ['val1', {abc: :cde}]
        expect(ret).to eq({'id' => 1})
      end
    end
  end
end
