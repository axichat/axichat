abstract class Cache {
  int maxBytes = 250 << 20;

  int add() {
    return 0;
  }

  int delete() {
    return 0;
  }
}

class MessageCache extends Cache {}
