# リクエストパラメータの日付（yyyy-MM-dd）を厳密に読む。Date.parse のように "2026/9/1" や "9/1" は受け付けない
module DateParam
  FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  # yyyy-MM-dd 形式の実在する日付だけを Date にして返す。不正なら nil
  def self.parse(value)
    return unless value.is_a?(String) && value.match?(FORMAT)

    Date.strptime(value, "%Y-%m-%d")
  rescue Date::Error
    nil
  end
end
