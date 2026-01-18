class RenameLocaleToProcessStatusOnLexemes < ActiveRecord::Migration[7.1]
  def up
    rename_column :lexemes, :locale, :process_status
    change_column_default :lexemes, :process_status, "pending"
    execute <<~SQL
      UPDATE lexemes
      SET process_status = 'pending'
      WHERE process_status IS NULL;
    SQL
    change_column_null :lexemes, :process_status, false
  end

  def down
    change_column_null :lexemes, :process_status, true
    change_column_default :lexemes, :process_status, nil
    rename_column :lexemes, :process_status, :locale
  end
end
