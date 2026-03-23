module test;
  int expected_msg_length = 4;
  int unsigned CONTROL_AND_CRC_BYTES = 4;
  initial begin
    if (expected_msg_length == CONTROL_AND_CRC_BYTES)
      $display("Match! expected=%0d, ctrl=%0d", expected_msg_length, CONTROL_AND_CRC_BYTES);
    else
      $display("Mismatch! expected=%0d, ctrl=%0d", expected_msg_length, CONTROL_AND_CRC_BYTES);
    $finish;
  end
endmodule
EOF
xrun test.sv
