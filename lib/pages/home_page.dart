import 'package:auto_report/pages/accouts_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // int _counter = 0;
  int _navIndex = 0;

  late PageController _pageViewController;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          PageView(
            controller: _pageViewController,
            onPageChanged: (index) => setState(() => _navIndex = index),
            children: <Widget>[
              const AccountsPage(),
              Center(
                child: Text('Second Page', style: textTheme.titleLarge),
              ),
            ],
          ),
        ],
      ),
      // body: Center(
      //   // child: Column(
      //   //   mainAxisAlignment: MainAxisAlignment.center,
      //   //   children: <Widget>[
      //   //     const Text(
      //   //       'You have pushed the button this many times:',
      //   //     ),
      //   //     Text(
      //   //       '$_counter',
      //   //       style: Theme.of(context).textTheme.headlineMedium,
      //   //     ),
      //   //   ],
      //   // ),
      // ),
      floatingActionButton: Visibility(
        visible: _navIndex == 0,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).pushNamed("/auth");
          },
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
        currentIndex: _navIndex,
        selectedItemColor: Colors.amber[800],
        onTap: (index) {
          setState(() => _navIndex = index);
          _pageViewController.jumpToPage(_navIndex);
        },
      ),
    );
  }
}
