local strings = {
  PERMALMALEXIA_DESCRIPTION = "Enables you (and @Kasskroot as well) to run any memento when the effect fades out !",
  PERMALMALEXIA_START = "PermAlmalexia started with <<1>>.",
  PERMALMALEXIA_END   = "PermAlmalexia will stop."
}

for stringId, stringValue in pairs(strings) do
  ZO_CreateStringId(stringId, stringValue)
  SafeAddVersion(stringId, 1)
end
