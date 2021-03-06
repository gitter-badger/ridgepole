if postgresql?
describe 'Ridgepole::Client#diff -> migrate' do
  context 'when change column' do
    let(:actual_dsl) {
      <<-RUBY
        create_table "clubs", force: :cascade do |t|
          t.string "name", limit: 255, default: "", null: false
        end

        add_index "clubs", ["name"], name: "idx_name", unique: true, using: :btree

        create_table "departments", primary_key: "dept_no", force: :cascade do |t|
          t.string "dept_name", limit: 40, null: false
        end

        create_table "dept_emp", id: false, force: :cascade do |t|
          t.integer "emp_no",              null: false
          t.string  "dept_no",   limit: 4, null: false
          t.date    "from_date",           null: false
          t.date    "to_date",             null: false
        end

        add_index "dept_emp", ["dept_no"], name: "idx_dept_emp_dept_no", using: :btree
        add_index "dept_emp", ["emp_no"], name: "idx_dept_emp_emp_no", using: :btree

        create_table "dept_manager", id: false, force: :cascade do |t|
          t.string  "dept_no",   limit: 4, null: false
          t.integer "emp_no",              null: false
          t.date    "from_date",           null: false
          t.date    "to_date",             null: false
        end

        add_index "dept_manager", ["dept_no"], name: "idx_dept_manager_dept_no", using: :btree
        add_index "dept_manager", ["emp_no"], name: "idx_dept_manager_emp_no", using: :btree

        create_table "employee_clubs", force: :cascade do |t|
          t.integer "emp_no",  null: false
          t.integer "club_id", null: false
        end

        add_index "employee_clubs", ["emp_no", "club_id"], name: "idx_employee_clubs_emp_no_club_id", using: :btree

        create_table "employees", primary_key: "emp_no", force: :cascade do |t|
          t.date   "birth_date",            null: false
          t.string "first_name", limit: 14, null: false
          t.string "last_name",  limit: 16, null: false
          t.date   "hire_date",             null: false
        end

        create_table "salaries", id: false, force: :cascade do |t|
          t.integer "emp_no",    null: false
          t.integer "salary",    null: false
          t.date    "from_date", null: false
          t.date    "to_date",   null: false
        end

        add_index "salaries", ["emp_no"], name: "idx_salaries_emp_no", using: :btree

        create_table "titles", id: false, force: :cascade do |t|
          t.integer "emp_no",               null: false
          t.string  "title",     limit: 50, null: false
          t.date    "from_date",            null: false
          t.date    "to_date"
        end

        add_index "titles", ["emp_no"], name: "idx_titles_emp_no", using: :btree
      RUBY
    }

    let(:expected_dsl) {
      <<-RUBY
        create_table "clubs", force: :cascade do |t|
          t.string "name", limit: 255, default: "", null: false
        end

        add_index "clubs", ["name"], name: "idx_name", unique: true, using: :btree

        create_table "departments", primary_key: "dept_no", force: :cascade do |t|
          t.string "dept_name", limit: 40, null: false
        end

        create_table "dept_emp", id: false, force: :cascade do |t|
          t.integer "emp_no",              null: false
          t.string  "dept_no",   limit: 4, null: false
          t.date    "from_date",           null: false
          t.date    "to_date",             null: false
        end

        add_index "dept_emp", ["dept_no"], name: "idx_dept_emp_dept_no", using: :btree
        add_index "dept_emp", ["emp_no"], name: "idx_dept_emp_emp_no", using: :btree

        create_table "dept_manager", id: false, force: :cascade do |t|
          t.string  "dept_no",   limit: 4, null: false
          t.integer "emp_no",              null: false
          t.date    "from_date",           null: false
          t.date    "to_date",             null: false
        end

        add_index "dept_manager", ["dept_no"], name: "idx_dept_manager_dept_no", using: :btree
        add_index "dept_manager", ["emp_no"], name: "idx_dept_manager_emp_no", using: :btree

        create_table "employee_clubs", force: :cascade do |t|
          t.integer "emp_no",  null: false
          t.integer "club_id"
        end

        add_index "employee_clubs", ["emp_no", "club_id"], name: "idx_employee_clubs_emp_no_club_id", using: :btree

        create_table "employees", primary_key: "emp_no", force: :cascade do |t|
          t.date   "birth_date",                            null: false
          t.string "first_name", limit: 14,                 null: false
          t.string "last_name",  limit: 20, default: "XXX", null: false
          t.date   "hire_date",                             null: false
        end

        create_table "salaries", id: false, force: :cascade do |t|
          t.integer "emp_no",    null: false
          t.integer "salary",    null: false
          t.date    "from_date", null: false
          t.date    "to_date",   null: false
        end

        add_index "salaries", ["emp_no"], name: "idx_salaries_emp_no", using: :btree

        create_table "titles", id: false, force: :cascade do |t|
          t.integer "emp_no",               null: false
          t.string  "title",     limit: 50, null: false
          t.date    "from_date",            null: false
          t.date    "to_date"
        end

        add_index "titles", ["emp_no"], name: "idx_titles_emp_no", using: :btree
      RUBY
    }

    before { subject.diff(actual_dsl).migrate }
    subject { client }

    it {
      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_truthy
      expect(subject.dump).to eq actual_dsl.strip_heredoc.strip
      delta.migrate
      expect(subject.dump).to eq expected_dsl.strip_heredoc.strip.gsub(/(\s*,\s*unsigned: false)?\s*,\s*null: true/, '')
    }

    it {
      delta = Ridgepole::Client.diff(actual_dsl, expected_dsl, reverse: true, enable_mysql_unsigned: true)
      expect(delta.differ?).to be_truthy
      expect(delta.script).to eq <<-RUBY.strip_heredoc.strip
        change_column("employee_clubs", "club_id", :integer, {:null=>false, :default=>nil})

        change_column("employees", "last_name", :string, {:limit=>16, :default=>nil})
      RUBY
    }

    it {
      delta = client(:bulk_change => true).diff(expected_dsl)
      expect(delta.differ?).to be_truthy
      expect(subject.dump).to eq actual_dsl.strip_heredoc.strip
      expect(delta.script).to eq <<-RUBY.strip_heredoc.strip
        change_table("employee_clubs", {:bulk => true}) do |t|
          t.change("club_id", :integer, {:null=>true, :default=>nil})
        end

        change_table("employees", {:bulk => true}) do |t|
          t.change("last_name", :string, {:limit=>20, :default=>"XXX"})
        end
      RUBY
      delta.migrate
      expect(subject.dump).to eq expected_dsl.strip_heredoc.strip.gsub(/(\s*,\s*unsigned: false)?\s*,\s*null: true/, '')
    }
  end

  context 'when string/text without limit (no change)' do
    let(:actual_dsl) {
      <<-RUBY
        create_table "clubs", force: :cascade do |t|
          t.string "name", default: "", null: false
          t.text "desc"
        end
      RUBY
    }

    let(:expected_dsl) {
      <<-RUBY
        create_table "clubs", force: :cascade do |t|
          t.string "name", default: "", null: false
          t.text "desc"
        end
      RUBY
    }

    before { subject.diff(actual_dsl).migrate }
    subject { client }

    it {
      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_falsey
    }
  end
end
end
