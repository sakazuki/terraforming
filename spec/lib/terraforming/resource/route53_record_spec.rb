require "spec_helper"

module Terraforming
  module Resource
    describe Route53Record do
      let(:client) do
        Aws::Route53::Client.new(stub_responses: true)
      end

      let(:hosted_zones) do
        [
          {
            id: "/hostedzone/ABCDEFGHIJKLMN",
            name: "hoge.net.",
            caller_reference: "ABCDEFGH-1234-IJKL-5678-MNOPQRSTUVWX",
            config: { private_zone: false },
            resource_record_set_count: 4
          },
          {
            id: "/hostedzone/OPQRSTUVWXYZAB",
            name: "fuga.net.",
            caller_reference: "ABCDEFGH-5678-IJKL-9012-MNOPQRSTUVWX",
            config: { private_zone: false },
            resource_record_set_count: 4
          },
          {
            id: "/hostedzone/ABCDEFINTERNAL",
            name: "hoge.net.",
            caller_reference: "ABCDEFIN-1234-TERN-5678-ALOPQRSTUVWX",
            config: { private_zone: true },
            resource_record_set_count: 4
          },
        ]
      end

      let(:hoge_resource_record_sets) do
        [
          {
            name: "hoge.net.",
            type: "A",
            ttl: 3600,
            weight: nil,
            set_identifier: "dev",
            resource_records: [
              { value: "123.456.78.90" },
              { value: "hoge.awsdns-60.org" },
            ],
          }
        ]
      end

      let(:fuga_resource_record_sets) do
        [
          {
            name: "www.fuga.net.",
            type: "A",
            ttl: nil,
            weight: 10,
            set_identifier: nil,
            alias_target: {
              hosted_zone_id: "ABCDEFGHIJ1234",
              dns_name: "fuga.net.",
              evaluate_target_health: false,
            },
          }
        ]
      end

      let(:hoge_internal_resource_record_sets) do
        [
          {
            name: "hoge.net.",
            type: "A",
            ttl: 3600,
            weight: nil,
            set_identifier: "dev",
            resource_records: [
              { value: "1.1.1.1" },
            ],
          }
        ]
      end

      before do
        client.stub_responses(:list_hosted_zones,
          hosted_zones: hosted_zones, marker: "", is_truncated: false, max_items: 1)
        client.stub_responses(:list_resource_record_sets, [
          { resource_record_sets: hoge_resource_record_sets, is_truncated: false, max_items: 1 },
          { resource_record_sets: fuga_resource_record_sets, is_truncated: false, max_items: 1 },
          { resource_record_sets: hoge_internal_resource_record_sets, is_truncated: false, max_items: 1 },
        ])
      end

      describe ".tf" do
        it "should generate tf" do
          expect(described_class.tf(client: client)).to eq <<-EOS
resource "aws_route53_record" "ABCDEFGHIJKLMN-hoge-net-A" {
    zone_id = "ABCDEFGHIJKLMN"
    name    = "hoge.net"
    type    = "A"
    records = ["123.456.78.90", "hoge.awsdns-60.org"]
    ttl     = "3600"
    set_identifier = "dev"

}

resource "aws_route53_record" "OPQRSTUVWXYZAB-www-fuga-net-A" {
    zone_id = "OPQRSTUVWXYZAB"
    name    = "www.fuga.net"
    type    = "A"
    weight  = 10

    alias {
        name    = "fuga.net"
        zone_id = "ABCDEFGHIJ1234"
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "ABCDEFINTERNAL-hoge-net-A" {
    zone_id = "ABCDEFINTERNAL"
    name    = "hoge.net"
    type    = "A"
    records = ["1.1.1.1"]
    ttl     = "3600"
    set_identifier = "dev"

}

        EOS
        end
      end

      describe ".tfstate" do
        it "should generate tfstate" do
          expect(described_class.tfstate(client: client)).to eq({
            "aws_route53_record.ABCDEFGHIJKLMN-hoge-net-A" => {
              "type" => "aws_route53_record",
              "primary" => {
                "id" => "ABCDEFGHIJKLMN_hoge.net_A",
                "attributes"=> {
                  "id" => "ABCDEFGHIJKLMN_hoge.net_A",
                  "name" => "hoge.net",
                  "type" => "A",
                  "zone_id" => "ABCDEFGHIJKLMN",
                  "records.#" => "2",
                  "ttl" => "3600",
                  "set_identifier" => "dev",
                },
              }
            },
            "aws_route53_record.OPQRSTUVWXYZAB-www-fuga-net-A" => {
              "type" => "aws_route53_record",
              "primary" => {
                "id" => "OPQRSTUVWXYZAB_www.fuga.net_A",
                "attributes" => {
                  "id" => "OPQRSTUVWXYZAB_www.fuga.net_A",
                  "name" => "www.fuga.net",
                  "type" => "A",
                  "zone_id" => "OPQRSTUVWXYZAB",
                  "alias.#" => "1",
                  "weight" => "10",
                },
              }
            },
            "aws_route53_record.ABCDEFINTERNAL-hoge-net-A" => {
              "type" => "aws_route53_record",
              "primary" => {
                "id" => "ABCDEFINTERNAL_hoge.net_A",
                "attributes"=> {
                  "id" => "ABCDEFINTERNAL_hoge.net_A",
                  "name" => "hoge.net",
                  "type" => "A",
                  "zone_id" => "ABCDEFINTERNAL",
                  "records.#" => "1",
                  "ttl" => "3600",
                  "set_identifier" => "dev",
                },
              }
            },
          })
        end
      end
    end
  end
end
