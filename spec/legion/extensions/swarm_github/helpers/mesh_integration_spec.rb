# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/helpers/mesh_integration'

RSpec.describe Legion::Extensions::SwarmGithub::Helpers::MeshIntegration do
  subject(:mod) { described_class }

  describe '.mesh_available?' do
    it 'returns falsy when Mesh::Client is not defined' do
      expect(mod.mesh_available?).to be_falsy
    end

    it 'returns truthy when Mesh::Client is defined' do
      stub_const('Legion::Extensions::Mesh::Client', Class.new)
      expect(mod.mesh_available?).to be_truthy
    end
  end

  describe '.workspace_available?' do
    it 'returns falsy when Swarm::Client is not defined' do
      expect(mod.workspace_available?).to be_falsy
    end

    it 'returns truthy when Swarm::Client is defined' do
      stub_const('Legion::Extensions::Swarm::Client', Class.new)
      expect(mod.workspace_available?).to be_truthy
    end
  end

  describe '.register_reviewer' do
    context 'when lex-mesh is not available' do
      it 'returns skipped hash' do
        result = mod.register_reviewer
        expect(result[:skipped]).to be true
        expect(result[:reason]).to eq('lex-mesh not available')
      end
    end

    context 'when lex-mesh is available' do
      let(:mesh_client) { instance_double('Legion::Extensions::Mesh::Client') }

      before do
        stub_const('Legion::Extensions::Mesh::Client', Class.new)
        allow(Legion::Extensions::Mesh::Client).to receive(:new).and_return(mesh_client)
        allow(mesh_client).to receive(:register).and_return({ success: true, registered: true,
                                                              agent_id: described_class::AGENT_ID })
      end

      it 'calls register on a Mesh::Client instance' do
        expect(mesh_client).to receive(:register).with(
          agent_id:     described_class::AGENT_ID,
          capabilities: described_class::CAPABILITIES,
          endpoint:     'local'
        )
        mod.register_reviewer
      end

      it 'returns the registration result' do
        result = mod.register_reviewer
        expect(result[:success]).to be true
        expect(result[:registered]).to be true
      end
    end
  end

  describe '.record_review_start' do
    let(:params) { { charter_id: 'cid-1', owner: 'org', repo: 'myrepo', pull_number: 42 } }

    context 'when lex-swarm is not available' do
      it 'returns nil' do
        expect(mod.record_review_start(**params)).to be_nil
      end
    end

    context 'when lex-swarm is available' do
      let(:swarm_client) { instance_double('Legion::Extensions::Swarm::Client') }

      before do
        stub_const('Legion::Extensions::Swarm::Client', Class.new)
        allow(Legion::Extensions::Swarm::Client).to receive(:new).and_return(swarm_client)
        allow(swarm_client).to receive(:workspace_put).and_return({ success: true })
      end

      it 'calls workspace_put with in_progress status' do
        expect(swarm_client).to receive(:workspace_put).with(
          charter_id: 'cid-1',
          key:        'review:org/myrepo#42',
          value:      hash_including(status: 'in_progress'),
          author:     described_class::AGENT_ID
        )
        mod.record_review_start(**params)
      end

      it 'includes started_at timestamp' do
        expect(swarm_client).to receive(:workspace_put).with(
          hash_including(value: hash_including(:started_at))
        )
        mod.record_review_start(**params)
      end
    end
  end

  describe '.record_review_complete' do
    let(:result) do
      {
        review: { status: 'reviewed' },
        post:   { posted: true, comments_count: 3 },
        notify: { notified: true }
      }
    end
    let(:params) { { charter_id: 'cid-1', owner: 'org', repo: 'myrepo', pull_number: 42, result: result } }

    context 'when lex-swarm is not available' do
      it 'returns nil' do
        expect(mod.record_review_complete(**params)).to be_nil
      end
    end

    context 'when lex-swarm is available' do
      let(:swarm_client) { instance_double('Legion::Extensions::Swarm::Client') }

      before do
        stub_const('Legion::Extensions::Swarm::Client', Class.new)
        allow(Legion::Extensions::Swarm::Client).to receive(:new).and_return(swarm_client)
        allow(swarm_client).to receive(:workspace_put).and_return({ success: true })
      end

      it 'calls workspace_put with final status from result' do
        expect(swarm_client).to receive(:workspace_put).with(
          charter_id: 'cid-1',
          key:        'review:org/myrepo#42',
          value:      hash_including(status: 'reviewed', posted: true, comments_count: 3),
          author:     described_class::AGENT_ID
        )
        mod.record_review_complete(**params)
      end

      it 'includes completed_at timestamp' do
        expect(swarm_client).to receive(:workspace_put).with(
          hash_including(value: hash_including(:completed_at))
        )
        mod.record_review_complete(**params)
      end

      it 'handles missing review status gracefully' do
        result_no_status = { review: nil, post: nil, notify: nil }
        expect(swarm_client).to receive(:workspace_put).with(
          hash_including(value: hash_including(status: 'unknown', posted: false, comments_count: 0))
        )
        mod.record_review_complete(**params, result: result_no_status)
      end
    end
  end
end
