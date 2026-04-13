require "rails_helper"

RSpec.describe CommandChain do
  let(:success_command) do
    Class.new(BaseCommand) do
      def call
        @context[:step1] = true
        @result = "step1 done"
        self
      end
    end
  end

  let(:second_success_command) do
    Class.new(BaseCommand) do
      def call
        @context[:step2] = true
        @result = "step2 done"
        self
      end
    end
  end

  let(:failing_command) do
    Class.new(BaseCommand) do
      def call
        add_error("something went wrong")
        self
      end
    end
  end

  describe "#call" do
    it "runs all commands in sequence" do
      chain = described_class.new(
        [success_command, second_success_command],
        {}
      ).call

      expect(chain).to be_success
      expect(chain.context[:step1]).to be true
      expect(chain.context[:step2]).to be true
      expect(chain.result).to eq("step2 done")
    end

    it "passes context between commands" do
      reader_command = Class.new(BaseCommand) do
        def call
          @result = @context[:step1]
          self
        end
      end

      chain = described_class.new(
        [success_command, reader_command],
        {}
      ).call

      expect(chain.result).to be true
    end

    it "stops on first failure" do
      chain = described_class.new(
        [success_command, failing_command, second_success_command],
        {}
      ).call

      expect(chain).not_to be_success
      expect(chain.errors).to eq(["something went wrong"])
      expect(chain.context[:step1]).to be true
      expect(chain.context[:step2]).to be_nil
    end

    it "returns errors from failing command" do
      chain = described_class.new([failing_command], {}).call

      expect(chain).not_to be_success
      expect(chain.errors).to eq(["something went wrong"])
    end

    it "works with initial context" do
      reader = Class.new(BaseCommand) do
        def call
          @result = @context[:input]
          self
        end
      end

      chain = described_class.new([reader], { input: 42 }).call

      expect(chain).to be_success
      expect(chain.result).to eq(42)
    end

    it "works with empty command list" do
      chain = described_class.new([], {}).call

      expect(chain).to be_success
      expect(chain.result).to be_nil
    end
  end
end
