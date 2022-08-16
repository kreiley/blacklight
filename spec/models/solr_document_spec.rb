# frozen_string_literal: true

RSpec.describe SolrDocument, api: true do
  describe "access methods" do
    let(:solrdoc) do
      described_class.new(id: '00282214', format: ['Book'], title_tsim: 'some-title')
    end

    describe "#[]" do
      subject { solrdoc[field] }

      context "with title_tsim" do
        let(:field) { :title_tsim }

        it { is_expected.to eq 'some-title' }
      end

      context "with format" do
        let(:field) { :format }

        it { is_expected.to eq ['Book'] }
      end
    end

    describe "#id" do
      subject { solrdoc.id }

      it { is_expected.to eq '00282214' }
    end
  end

  describe '.attribute' do
    subject(:title) { document.title }

    let(:doc_class) do
      Class.new(SolrDocument) do
        attribute :title, :string, 'title_tesim'
        attribute :author, :array, 'author_tesim', of: :string
        attribute :first_author, :select, 'author_tesim', by: :min
        attribute :date, :date, field: 'date_dtsi'
        attribute :whatever, :string, default: ->(*) { 'default_value' }
      end
    end
    let(:document) do
      doc_class.new(id: '123',
                    title_tesim: ['Good Omens'],
                    author_tesim: ['Neil Gaiman', 'Terry Pratchett'],
                    date_dtsi: '1990-01-01T00:00:00Z')
    end

    it "casts the attributes" do
      expect(document.title).to eq 'Good Omens'
      expect(document.author).to eq ['Neil Gaiman', 'Terry Pratchett']
      expect(document.first_author).to eq 'Neil Gaiman'
      expect(document.date).to eq Date.new(1990)
      expect(document.whatever).to eq 'default_value'
    end
  end
end
