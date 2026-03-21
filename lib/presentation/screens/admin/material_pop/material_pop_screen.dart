import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/pop_material.dart';
import '../../../../config/theme_config.dart';
import '../../../providers/pop_provider.dart';
import '../../../providers/auth_provider.dart';

class MaterialPopScreen extends ConsumerStatefulWidget {
  const MaterialPopScreen({super.key});

  @override
  ConsumerState<MaterialPopScreen> createState() => _MaterialPopScreenState();
}

class _MaterialPopScreenState extends ConsumerState<MaterialPopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterMarca; // null = todas, SHELL, QUALID

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showManageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: const Text('Crear nuevo material'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/admin/material-pop/nuevo');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Editar materiales existentes'),
              subtitle: const Text('Toca un material en el Stock para editarlo'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final sedeApp = user?.isOwner == true ? null : user?.sede?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material POP'),
        backgroundColor: ThemeConfig.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Stock'),
            Tab(icon: Icon(Icons.swap_vert), text: 'Movimientos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StockTab(sedeApp: sedeApp, filterMarca: _filterMarca, onFilterChanged: (m) => setState(() => _filterMarca = m)),
          _MovementsTab(sedeApp: sedeApp),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'manage',
            onPressed: () => _showManageMenu(context),
            backgroundColor: Colors.grey[700],
            child: const Icon(Icons.settings, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'register',
            onPressed: () => context.push('/admin/material-pop/registro'),
            backgroundColor: ThemeConfig.primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Registrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ============================================
// TAB DE STOCK
// ============================================
class _StockTab extends ConsumerWidget {
  final String? sedeApp;
  final String? filterMarca;
  final ValueChanged<String?> onFilterChanged;

  const _StockTab({this.sedeApp, this.filterMarca, required this.onFilterChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(popStockProvider(sedeApp));

    return Column(
      children: [
        // Filtros por marca
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'Todas',
                selected: filterMarca == null,
                onTap: () => onFilterChanged(null),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Shell',
                selected: filterMarca == 'SHELL',
                onTap: () => onFilterChanged('SHELL'),
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Qualid',
                selected: filterMarca == 'QUALID',
                onTap: () => onFilterChanged('QUALID'),
                color: Colors.blue,
              ),
            ],
          ),
        ),
        Expanded(
          child: stockAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (stocks) {
              final filtered = filterMarca == null
                  ? stocks
                  : stocks.where((s) => s.material?.marca == filterMarca).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Sin stock registrado', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Registra un ingreso para comenzar', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(popStockProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final stock = filtered[index];
                    return GestureDetector(
                      onTap: () {
                        if (stock.material != null) {
                          context.push('/admin/material-pop/editar', extra: stock.material);
                        }
                      },
                      child: _StockCard(stock: stock),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StockCard extends StatelessWidget {
  final PopStock stock;
  const _StockCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    final material = stock.material;
    if (material == null) return const SizedBox.shrink();

    final isNegative = stock.cantidad < 0;
    final isLow = stock.cantidad > 0 && stock.cantidad <= 5;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: material.marca == 'SHELL'
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.blue.withValues(alpha: 0.1),
          child: Icon(
            _getCategoryIcon(material.categoria),
            color: material.marca == 'SHELL' ? Colors.red : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          material.nombre,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Text(
              '${material.marca} - ${material.tipoMaterial}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            if (material.isLinked) ...[
              const SizedBox(width: 6),
              Icon(Icons.link, size: 12, color: Colors.green[400]),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isNegative
                ? Colors.red.withValues(alpha: 0.1)
                : isLow
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${stock.cantidad}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isNegative ? Colors.red : isLow ? Colors.orange : Colors.green[700],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoria) {
    switch (categoria) {
      case 'ENTREGABLE':
        return Icons.card_giftcard;
      case 'MATERIAL DE APOYO':
        return Icons.support;
      case 'INTERIOR':
        return Icons.store;
      case 'EXTERIOR':
        return Icons.storefront;
      default:
        return Icons.inventory;
    }
  }
}

// ============================================
// TAB DE MOVIMIENTOS
// ============================================
class _MovementsTab extends ConsumerWidget {
  final String? sedeApp;
  const _MovementsTab({this.sedeApp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(popMovementsProvider(sedeApp));

    return movementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (movements) {
        if (movements.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_vert, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Sin movimientos registrados', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(popMovementsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: movements.length,
            itemBuilder: (context, index) {
              final mov = movements[index];
              final isIngreso = mov.tipo == 'ingreso';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIngreso
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    child: Icon(
                      isIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIngreso ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(
                    mov.material?.nombre ?? 'Material',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${isIngreso ? "Ingreso" : "Egreso"} - ${mov.sedeApp}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      if (mov.observaciones != null && mov.observaciones!.isNotEmpty)
                        Text(
                          mov.observaciones!,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (mov.createdAt != null)
                        Text(
                          _formatDate(mov.createdAt!),
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                    ],
                  ),
                  trailing: Text(
                    '${isIngreso ? "+" : "-"}${mov.cantidad}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isIngreso ? Colors.green : Colors.red,
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================
// FILTER CHIP
// ============================================
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? ThemeConfig.primaryColor).withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? (color ?? ThemeConfig.primaryColor) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (color ?? ThemeConfig.primaryColor) : Colors.grey[600],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
