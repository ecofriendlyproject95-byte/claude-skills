import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent.dart';
import '../services/api_service.dart';
import '../widgets/agent_card.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Agent> _agents = [];
  String? _error;
  bool _loading = true;
  String _selectedDomain = 'All';

  @override
  void initState() { super.initState(); _loadAgents(); }

  Future<void> _loadAgents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final agents = await context.read<ApiService>().fetchAgents();
      setState(() { _agents = agents; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<String> get _domains => ['All', ..._agents.map((a) => a.domain).toSet()];
  List<Agent> get _filtered => _selectedDomain == 'All'
      ? _agents : _agents.where((a) => a.domain == _selectedDomain).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Agents', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Your expert team, on demand', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            if (_agents.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _domains.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _domains[i];
                    final sel = d == _selectedDomain;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDomain = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFF6366F1) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey.shade600)),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('Cannot connect to backend', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(onPressed: _loadAgents, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                          ],
                        ))
                      : RefreshIndicator(
                          onRefresh: _loadAgents,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => AgentCard(
                              agent: _filtered[i],
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(agent: _filtered[i]))),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
