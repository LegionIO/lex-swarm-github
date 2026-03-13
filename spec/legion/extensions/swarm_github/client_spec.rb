# frozen_string_literal: true

require 'legion/extensions/swarm_github/client'

RSpec.describe Legion::Extensions::SwarmGithub::Client do
  it 'responds to github swarm runner methods' do
    client = described_class.new
    expect(client).to respond_to(:ingest_issue)
    expect(client).to respond_to(:claim_issue)
    expect(client).to respond_to(:start_fix)
    expect(client).to respond_to(:submit_validation)
    expect(client).to respond_to(:attach_pr)
    expect(client).to respond_to(:get_issue)
    expect(client).to respond_to(:issues_by_state)
    expect(client).to respond_to(:pipeline_status)
  end
end
