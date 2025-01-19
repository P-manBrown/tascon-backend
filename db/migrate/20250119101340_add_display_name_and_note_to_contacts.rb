class AddDisplayNameAndNoteToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :display_name, :string
    add_column :contacts, :note, :text
  end
end
