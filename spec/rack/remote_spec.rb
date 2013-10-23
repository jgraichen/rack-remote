require 'spec_helper'

describe Rack::Remote do
  include Rack::Test::Methods

  let(:inner_app) { lambda { |_| [200, {'Content-Type' => 'text/plain'}, 'All good!'] } }
  let(:app) { Rack::Remote.new(inner_app) }
  let(:block) { lambda  { |_, _, _| } }

  after(:each) { Rack::Remote.clear }

  describe 'call' do
    before { Rack::Remote.register :factory_girl, &block }

    context 'with intercept call' do
      let(:request) { -> { post '/', {}, {'HTTP_X_RACK_REMOTE_CALL' => 'factory_girl'} }}

      it 'should invoke registered call' do
        expect(block).to receive(:call)
        request.call
      end

      it 'should not delegate request to inner app' do
        expect(inner_app).to_not receive(:call)
        request.call
      end
    end

    context 'with non-rack-remote call' do
      let(:request) { -> { post '/' }}

      it 'should delegate request to inner app' do
        expect(inner_app).to receive(:call).and_call_original
        request.call
      end
    end
  end

  describe 'class' do
    describe '#register' do

      it 'should add callback' do
        expect {
          Rack::Remote.register :factory_girl, &block
        }.to change{ Rack::Remote.calls.size }.from(0).to(1)
      end

      it 'should add given callback' do
        Rack::Remote.register :factory_girl, &block
        expect(Rack::Remote.calls.values.first).to equal block
      end
    end

    describe '#add' do
      subject { -> { Rack::Remote.add :users, url: 'http://users.example.org' } }

      it 'should add a remote' do
        expect { subject.call }.to change { Rack::Remote.remotes.size }.from(0).to(1)
      end

      it 'should add given remote' do
        subject.call
        expect(Rack::Remote.remotes[:users]).to eq url: 'http://users.example.org'
      end
    end

    describe '#invoke' do
      before { stub_request(:any, /users\.example\.org/).to_rack(app) }
      before { Rack::Remote.register :factory_girl, &block }
      before { Rack::Remote.add :users, url: 'http://users.example.org' }

      it 'should invoke remote call' do
        expect(block).to receive(:call).with({ 'param1' => 'val1' }, kind_of(Hash), kind_of(Rack::Request)).and_return({id: 1})
        ret = Rack::Remote.invoke :users, :factory_girl, param1: 'val1'
        expect(ret).to eq({'id' => 1})
      end

      it 'should invoke remote call (2)' do
        expect(block).to receive(:call).with({ 'param1' => ['val1', {'abc' => 'cde'}] }, kind_of(Hash), kind_of(Rack::Request)).and_return({id: 1})
        ret = Rack::Remote.invoke :users, :factory_girl, param1: ['val1', {abc: :cde}]
        expect(ret).to eq({'id' => 1})
      end
    end
  end
end
