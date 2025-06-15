import 'package:flutter/material.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  String inputValue = ""; // ✅ Moved outside build to preserve state
  String calculatorValue = "";
  String operator = "";

  @override
  Widget build(BuildContext context) {
    double size = 80; // ✅ Updated from 0 to a visible size

    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Container(
              alignment: Alignment.bottomRight,
              child: Text(
                inputValue,
                style: const TextStyle(color: Colors.white, fontSize: 100),
              ),
            ),

            Column(
              children: [
                Row(
                  children: [
                    calc("7", Colors.white38, size),
                    calc("8", Colors.white38, size),
                    calc("9", Colors.white38, size),
                    calc("/", Colors.orange, size),
                  ],
                ),
                Row(
                  children: [
                    calc("4", Colors.white38, size),
                    calc("5", Colors.white38, size),
                    calc("6", Colors.white38, size),
                    calc("*", Colors.orange, size),
                  ],
                ),
                Row(
                  children: [
                    calc("1", Colors.white38, size),
                    calc("2", Colors.white38, size),
                    calc("3", Colors.white38, size),
                    calc("-", Colors.orange, size),
                  ],
                ),
                Row(
                  children: [
                    calc("0", Colors.white38, size),
                    calc(".", Colors.white38, size),
                    calc("=", Colors.white38, size),
                    calc("+", Colors.orange, size),
                  ],
                ),
              ],
            ),

            calc("Clear", Colors.black, size),
          ],
        ),
      ),
    );
  }

  Widget calc(String text, Color bgclr, double size) {
    return InkWell(
      onTap: () {
        if (text == "Clear") {
          setState(() {
            inputValue = "";
            calculatorValue = "";
            operator = "";
          });
        } else if (text == "+" || text == "-" || text == "*" || text == "/") {
          setState(() {
            calculatorValue = inputValue;
            inputValue = "";
            operator = text;
          });
        } else if (text == "=") {
          setState(() {
            double calc = double.parse(calculatorValue);
            double input = double.parse(inputValue);

            if (operator == "+") {
              inputValue = (calc + input).toString();
            } else if (operator == "-") {
              inputValue = (calc - input).toString();
            } else if (operator == "*") {
              inputValue = (calc * input).toString();
            } else if (operator == "/") {
              inputValue = (calc / input).toString();
            }
          });
        } else {
          setState(() {
            inputValue = inputValue + text;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgclr,
          borderRadius: BorderRadius.circular(100),
        ),
        margin: const EdgeInsets.all(10),
        height: size,
        width: size,
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 30),
        ),
      ),
    );
  }
}
