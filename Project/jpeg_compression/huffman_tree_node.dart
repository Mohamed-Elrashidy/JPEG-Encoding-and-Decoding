class HuffmanTreeNode{
  int? value;
  HuffmanTreeNode? left;
  HuffmanTreeNode? right;
  int childrenCount = 0;//included me
  HuffmanTreeNode({this.value, this.left, this.right, this.childrenCount = 0});
}