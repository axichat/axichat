extension BoolTool on bool {
  int toSign() => this ? 1 : -1;

  int toBinary() => this ? 1 : 0;
}
