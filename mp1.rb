describe Contract, type: :model do
  # …
      describe '.effective_for' do
        RSpec::Matchers.define :have_ranged do
              |contract, valid_from, valid_until, position = 1|
          match do |actual|
            actual[position - 1]&.id == contract.id and
                actual[position - 1]&.effective_valid_from == valid_from and
                actual[position - 1]&.effective_valid_until == valid_until
          end
        end

        let(:following_master_contract) do
          create :master_contract,
              active: other_active,
              client_instance: client_instance,
              prev_master_contract: master_contract,
              valid_from: next_valid_from,
              valid_until: next_valid_until
        end
        let(:other_master_contract) do
          create :master_contract,
              active: other_active,
              subdomain: other_subdomain,
              prev_master_contract: prev_master_contract,
              service_type: other_service_type,
              valid_from: other_valid_from,
              valid_until: other_valid_until
        end
        let(:next_valid_from)  {mc_valid_until + 1.day}
        let(:next_valid_until) {mc_valid_until + 3.months}
        let(:other_active) {true}
        let(:other_client_instance) {mock_client_instance subdomain: other_subdomain}
        let(:other_service_type) {service_type}
        let(:other_subdomain) {subdomain}
        let(:other_valid_from) {mc_valid_from + 1.week}
        let(:other_valid_until) {mc_valid_until + 1.week}
        let(:supplier_id) {mock_supplier.id}

        subject {Contract.effective_for supplier_id}

        it 'returns an ActiveRecord::Relation' do
          is_expected.to be_an ActiveRecord::Relation
        end

        describe 'the Array content and its :effective_valid_* dates' do
          context 'when only one contract exists for the supplier_id' do
            let!(:contract) do
              create :contract,
                  master_contract: master_contract,
                  valid_from: valid_from,
                  valid_until: valid_until,
                  supplier_id: supplier_id
            end
            let(:valid_from) {}
            let(:valid_until) {}

            context 'with validity dates present' do
              context 'when the validity dates are inside the dates of MasterContract' do
                let(:valid_from) {1.day.ago.to_date}
                let(:valid_until) {1.day.from_now.to_date}

                it 'has only it with its validity dates' do
                  is_expected.to have_ranged contract, valid_from, valid_until
                end
              end   # when the validity dates are inside the dates of MasterContract

              context 'when the validity dates are outside the dates of MasterContract' do
                let(:valid_from) {mc_valid_from - 1.day}
                let(:valid_until) {mc_valid_until + 2.weeks}

                context 'and there is no following MasterContract' do
                  it 'has only it with validity dates of the master_contract' do
                    is_expected.to have_ranged contract, mc_valid_from, mc_valid_until
                  end
                end   # and there is no following MasterContract

                context 'and there is a following MasterContract' do
                  let!(:following_master_contract_) {following_master_contract}

                  it 'has only it with valid_from of own MC its valid_until' do
                    logger.debug "Rspec Contract@#{__LINE__}.effective_for #{valid_from} #{next_valid_until} #{subject.first.id}-#{subject.first.subdomain} #{subject.first.effective_valid_from} #{subject.first.effective_valid_until}"
                    is_expected.to have_ranged contract, mc_valid_from, valid_until
                  end
                end   # and there is a following MasterContract
              end   # when the validity dates are outside the dates of MasterContract
            end   # with validity dates present

            context 'that has no validity dates' do
              context 'there are no previous nor following master contract' do
                it 'has only it with the validity dates of the master_contract' do
                  is_expected
                      .to have_ranged contract, mc_valid_from, mc_valid_until
                end
              end   # there are no following master contract

              context 'there is a previous but not following master contract' do
                let(:prev_master_contract) do
                  create :master_contract,
                      client_instance: client_instance,
                      valid_from: mc_valid_from - 6.months,
                      valid_until: mc_valid_from - 1.day
                end

                it 'has only it with the validity dates of the master_contract' do
                  is_expected
                      .to have_ranged contract, mc_valid_from, mc_valid_until
                end
              end   # there is a previous but not following master contract

              context 'there is no previous but an ajointed following master contract' do
                let!(:following_master_contract) do
                  create :master_contract,
                      active: other_active,
                      client_instance: client_instance,
                      prev_master_contract: master_contract,
                      valid_from: next_valid_from,
                      valid_until: next_valid_until
                end

                it 'has only it with the valid_from of its master_contract and valid_until of the next one' do
                  # logger.debug "Rspec Contract@#{__LINE__}.effective_for #{}"
                  is_expected
                      .to have_ranged contract, mc_valid_from, next_valid_until
                end
              end   # there is no previous but an ajointed following master contract

              context 'there is no previous but an overlapping following master contract' do
                let!(:following_master_contract) do
                  create :master_contract,
                      client_instance: client_instance,
                      prev_master_contract: master_contract,
                      valid_from: next_valid_from,
                      valid_until: next_valid_until
                end
                let(:next_valid_from)  {mc_valid_until - 1.month}

                it 'has only it with the next_valid_from of its master_contract and next_valid_until of the next one' do
                  is_expected
                      .to have_ranged contract, mc_valid_from, next_valid_until
                end
              end   # there is no previous but an overlapping following master contract
            end   # that has no validity dates
          end   # when only one contract exists for the supplier_id

          context 'there are two contracts for the supplier_id' do
            let!(:contract1) do
              create :contract,
                  active: active1,
                  master_contract: c1_mc,
                  valid_from: valid_from1,
                  valid_until: valid_until1,
                  supplier_id: supplier_id
            end
            let!(:contract2) do
              create :contract,
                  active: active2,
                  master_contract: c2_mc,
                  valid_from: valid_from2,
                  valid_until: valid_until2,
                  supplier_id: supplier_id
            end
            let(:c1_mc) {master_contract}
            let(:c2_mc) {master_contract}
            let(:active1) {true}
            let(:active2) {true}
            let(:valid_from1) {}
            let(:valid_until1) {}
            let(:valid_from2) {}
            let(:valid_until2) {}

            context 'belonging to the same MasterContract' do
              context 'having no valid_* present except valid_until for the 1st' do
                let(:valid_until1) {mc_valid_until - 1.month}

                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end

                it 'first goes the 1st with valid_from of the MC and its valid_until' do
                  is_expected
                      .to have_ranged contract1, mc_valid_from, valid_until1
                end

                it 'next goes the 2nd with the same valid_from and valid_until of the MasterContract' do
                  is_expected
                      .to have_ranged contract2, mc_valid_from, mc_valid_until, 2
                end
              end   # having no valid_* present except valid_until for the 1st

              context 'having no valid_* present except valid_from for the 2nd' do
                let(:valid_from2) {mc_valid_until - 1.month}

                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end

                it 'first goes the 1st with MC valid_from and valid_until preceding one day of the 2nd valid_from' do
                  is_expected
                      .to have_ranged contract1, mc_valid_from, valid_from2 - 1.day
                end

                it 'next goes the second with its valid_from and valid_until of the MasterContract' do
                  is_expected
                      .to have_ranged contract2, valid_from2, mc_valid_until, 2
                end
              end   # having no valid_* present except valid_from for the 2nd
            end   # belonging to the same MasterContract

            context 'belonging to the consequent MasterContracts' do
              let(:c2_mc) {following_master_contract}

              context 'and both have no valid_* dates' do
                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end

                it 'first goes the 1st with the validity dates of its MC' do
                  is_expected
                      .to have_ranged contract1, mc_valid_from, mc_valid_until
                end

                it 'next goes the 2nd with the validity dates of its MC' do
                  is_expected
                      .to have_ranged contract2, next_valid_from, next_valid_until, 2
                end

                context 'but when the first contract becomes inactive' do
                  let(:active1) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 2nd with validity dates of its MC' do
                    is_expected
                        .to have_ranged contract2, next_valid_from, next_valid_until
                  end
                end   # but when the first contract becomes inactive

                context 'but when the second contract becomes inactive' do
                  let(:active2) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 1st with valid_from of its MC and valid_until of the following' do
                    is_expected
                        .to have_ranged contract1, mc_valid_from, next_valid_until
                  end
                end   # but when the second contract becomes inactive

                context 'but when the first MasterContract becomes inactive' do
                  let(:mc_active) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 2nd with validity dates of its MC' do
                    is_expected
                        .to have_ranged contract2, next_valid_from, next_valid_until
                  end
                end   # but when the first MasterContract becomes inactive

                context 'but when the second MasterContract becomes inactive' do
                  let(:other_active) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 1st with validity dates of its MC' do
                    is_expected
                        .to have_ranged contract1, mc_valid_from, mc_valid_until
                  end
                end   # but when the second MasterContract becomes inactive
              end   # and both have no valid_* dates

              context 'and 1st has no valid_until while the 2nd has valid_from later than of its MC' do
                let(:valid_from2) {next_valid_from + 1.week}

                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end

                it 'first goes the 1st with the valid_until lasting to the day before valid_from of the 2nd' do
                  is_expected
                      .to have_ranged contract1, mc_valid_from, valid_from2 - 1.day
                end

                it 'next goes the 2nd with its valid_from and valid_until of its MC' do
                  is_expected
                      .to have_ranged contract2, valid_from2, next_valid_until, 2
                end

                context 'but when the first contract becomes inactive' do
                  let(:active1) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 2nd with its valid_from and valid_until of its MC' do
                    is_expected
                        .to have_ranged contract2, valid_from2, next_valid_until
                  end
                end   # but when the first contract becomes inactive

                context 'but when the second contract becomes inactive' do
                  let(:active2) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 1st with valid_from of its MC and valid_until of the following' do
                    is_expected
                        .to have_ranged contract1, mc_valid_from, next_valid_until
                  end
                end   # but when the second contract becomes inactive

                context 'but when the first MasterContract becomes inactive' do
                  let(:mc_active) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 2nd with its valid_from and valid_until of its MC' do
                    is_expected
                        .to have_ranged contract2, valid_from2, next_valid_until
                  end
                end   # but when the first MasterContract becomes inactive

                context 'but when the second MasterContract becomes inactive' do
                  let(:other_active) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 1st with validity dates of its MC' do
                    is_expected
                        .to have_ranged contract1, mc_valid_from, mc_valid_until
                  end
                end   # but when the second MasterContract becomes inactive
              end   # and 1st has no valid_until while the 2nd has valid_from

              context 'and both have validity dates inside their MCs with the 1st ending later' do
                let(:valid_from1)  {mc_valid_from + 1.week}
                let(:valid_until1) {mc_valid_until + 2.weeks}
                let(:valid_from2)  {next_valid_from + 1.week}
                let(:valid_until2) {next_valid_until - 1.week}

                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end

                it 'first goes the 1st with its valid_from1 and valid_until just before the 2nd' do
                  is_expected
                      .to have_ranged contract1, valid_from1, valid_from2 - 1.day
                end

                it 'next goes the 2nd with its validity dates' do
                  is_expected
                      .to have_ranged contract2, valid_from2, valid_until2, 2
                end

                context 'but when the first contract becomes inactive' do
                  let(:active1) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 2nd with its validity dates' do
                    logger.debug "Rspec Contract@#{__LINE__}.effective_for #{valid_from2} #{valid_until2} #{subject.first.id} #{subject.first.effective_valid_from} #{subject.first.effective_valid_until}"
                    is_expected
                        .to have_ranged contract2, valid_from2, valid_until2
                  end
                end   # but when the first contract becomes inactive

                context 'but when the second contract becomes inactive' do
                  let(:active2) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 1st with its validity dates' do
                    is_expected
                        .to have_ranged contract1, valid_from1, valid_until1
                  end
                end   # but when the second contract becomes inactive

                context 'but when the first MasterContract becomes inactive' do
                  let(:mc_active) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 2nd with its validity dates' do
                    logger.debug "Rspec Contract@#{__LINE__}.effective_for #{valid_from2} #{valid_until2} #{subject.first.id} #{subject.first.effective_valid_from} #{subject.first.effective_valid_until}"
                    is_expected
                        .to have_ranged contract2, valid_from2, valid_until2
                  end
                end   # but when the first MasterContract becomes inactive

                context 'but when the second MasterContract becomes inactive' do
                  let(:other_active) {false}

                  it 'contains only one contract' do
                    expect(subject.to_a.size).to be 1
                  end

                  it 'namely the 1st with its valid_from and valid_until immediately before second MC' do
                    is_expected
                        .to have_ranged contract1, valid_from1, next_valid_from - 1.day
                  end
                end   # but when the second MasterContract becomes inactive
              end   # and both have validity dates inside their MCs with the 1st ending later
            end   # belonging to the consequent MasterContracts

            context 'belonging to MasterContracts with different subdomains' do
              let(:c2_mc) {other_master_contract}
              let(:other_subdomain) {'boing'}

              context 'without optional second parameter :subdomain' do
                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end
              end   # without optional second parameter :subdomain

              context 'with optional second parameter :subdomain' do
                subject {Contract.effective_for supplier_id, other_subdomain}

                it 'contains only one contract' do
                  expect(subject.to_a.size).to be 1
                end

                it 'contains the contract with the corresponding subdomain' do
                  expect(subject.first.subdomain).to eq other_subdomain
                end
              end   # with optional second parameter :subdomain
            end   # belonging to MasterContracts with different subdomains

            context 'belonging to MasterContracts with different service_types' do
              let(:c2_mc) {other_master_contract}
              let(:other_service_type) {'location'}

              context 'without optional third parameter :service_type' do
                it 'contains two contracts' do
                  expect(subject.to_a.size).to be 2
                end
              end   # without optional third parameter :service_type

              context 'with optional third parameter :service_type' do
                subject {Contract.effective_for supplier_id, nil, other_service_type}

                it 'contains only one contract' do
                  expect(subject.to_a.size).to be 1
                end

                it 'contains the contract with the corresponding service_type' do
                  expect(subject.first.service_type).to eq other_service_type
                end
              end   # with optional third parameter :service_type
            end   # belonging to MasterContracts with different service_types
          end   # there are two contracts for the supplier_id
        end   # the Array content and its :effective_valid_* dates
      end   # .effective_for
end

class Contract < ApplicationRecord
  # …
  scope :effective_for, ->(supplier_id, subdomain = nil, service_type = nil) do
    attrs = Contract.attribute_names.map{|name| "contracts.#{name}"}.join(', ')
    flat = Contract.extended_for(supplier_id, subdomain, service_type).to_sql
    select(<<-SQL.strip_heredoc
        #{attrs}, contracts.service_type, contracts.subdomain, contracts.effective_valid_from,
        DATE(CASE
          WHEN MIN(follows.effective_valid_from) IS NOT NULL
              AND MIN(follows.effective_valid_from) < contracts.effective_valid_until
          THEN MIN(follows.effective_valid_from) - INTERVAL 1 DAY
          ELSE contracts.effective_valid_until
        END) AS effective_valid_until
      SQL
    )
    .from("(#{flat}) AS contracts")
    .joins(<<-SQL.strip_heredoc
      LEFT JOIN (#{flat}) AS follows
        ON contracts.service_type = follows.service_type
          AND contracts.subdomain = follows.subdomain
          AND contracts.effective_valid_from < follows.effective_valid_from
    SQL
    )
    .group(<<-SQL.strip_heredoc
      #{attrs}, contracts.service_type, contracts.subdomain,
      contracts.effective_valid_from, contracts.effective_valid_until
    SQL
    )
    .order('effective_valid_from')
  end

  scope :extended_for, ->(supplier_id, subdomain = nil, service_type = nil) do
    res = select(<<-SQL.strip_heredoc
        contracts.*,
        DATE(GREATEST(COALESCE(contracts.valid_from, master_contracts.valid_from),
                master_contracts.valid_from))
          AS effective_valid_from,
        DATE(LEAST(COALESCE(contracts.valid_until,
              GREATEST(master_contracts.valid_until,
                      COALESCE(following_master_contracts.valid_until,
                               master_contracts.valid_until))),
              GREATEST(master_contracts.valid_until,
                      COALESCE(following_master_contracts.valid_until,
                               master_contracts.valid_until))))
          AS effective_valid_until,
        master_contracts.service_type,
        master_contracts.subdomain
      SQL
    ).joins(<<-SQL.strip_heredoc
        INNER JOIN master_contracts
            ON master_contracts.id = contracts.master_contract_id
        LEFT OUTER JOIN master_contracts following_master_contracts
          ON following_master_contracts.prev_master_contract_id =
              master_contracts.id AND following_master_contracts.active
      SQL
    )
        .where('contracts.active')
        .where('master_contracts.active')
        .where(contracts: {supplier_id: supplier_id})
    res = res.where master_contracts: {service_type: service_type} if service_type
    res = res.where master_contracts: {subdomain: subdomain} if subdomain
    res
  end
end
