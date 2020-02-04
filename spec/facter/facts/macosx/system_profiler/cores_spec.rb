# frozen_string_literal: true

describe 'Macosx SystemProfilerCores' do
  context '#call_the_resolver' do
    let(:value) { '' }
    let(:expected_resolved_fact) { double(Facter::ResolvedFact, name: 'system_profiler.cores', value: value) }
    subject(:fact) { Facter::Macosx::SystemProfilerCores.new }

    before do
      expect(Facter::Resolvers::SystemProfiler).to receive(:resolve).with(:total_number_of_cores).and_return(value)
      expect(Facter::ResolvedFact).to receive(:new)
        .with('system_profiler.cores', value)
        .and_return(expected_resolved_fact)
    end

    it 'returns system_profiler.cores fact' do
      expect(fact.call_the_resolver).to eq(expected_resolved_fact)
    end
  end
end