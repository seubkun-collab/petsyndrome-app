import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../models/ingredient.dart';
import '../../models/packaging.dart';
import '../../models/recipe.dart';
import '../../services/data_service.dart';
import '../../services/cost_calculator.dart';
import '../../utils/theme.dart';
import '../../utils/formatter.dart';

// 포장중량 카테고리
enum WeightCategory { under100, over100, bulk }

// 히스토리 항목 (앱 내 메모리 저장 + 레시피 ID 연결)
class _HistoryItem {
  final String recipeId;
  final String label;
  final double price;
  final String detail;
  final String weightCategory;
  final DateTime time;
  final String workerName;
  final bool isMixed;
  final String ingredientsLabel;
  final double weightG;
  final double bulkMoqKg;

  _HistoryItem({
    required this.recipeId,
    required this.label,
    required this.price,
    required this.detail,
    required this.weightCategory,
    required this.time,
    required this.workerName,
    required this.isMixed,
    required this.ingredientsLabel,
    required this.weightG,
    this.bulkMoqKg = 10.0,
  });

  String get shareText {
    final buf = StringBuffer();
    buf.writeln('[ 펫신드룸 단가 견적 ]');
    buf.writeln('─────────────────────');
    buf.writeln('원료: $ingredientsLabel');
    buf.writeln('포장: $label');
    buf.writeln('예상 단가: ${Fmt.won(price)}');
    if (weightCategory == 'bulk') {
      buf.writeln('벌크 기준: ${bulkMoqKg.toStringAsFixed(0)}kg (MOQ 단위)');
    }
    if (detail.isNotEmpty) buf.writeln('참고: $detail');
    if (workerName.isNotEmpty) buf.writeln('작업자: $workerName');
    buf.writeln('계산일시: ${Fmt.datetime(time)}');
    buf.writeln('─────────────────────');
    buf.writeln('※ 본 견적은 예상 단가입니다. 확정 견적은 펫신드룸으로 문의해 주세요.');
    return buf.toString();
  }
}

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  bool _isMixed = false;

  // 작업자
  final _workerCtrl = TextEditingController();

  // 단미
  Ingredient? _selectedIngredient;

  // 혼합
  final List<_MixItem> _mixItems = [];

  // 포장중량 카테고리
  WeightCategory _weightCat = WeightCategory.under100;
  final _weightCtrl = TextEditingController();
  String? _weightError;

  // 용기 종류
  String _packagingType = 'vinyl';

  // 결과
  CostResult? _result;
  String? _recommendedContainer;
  String? _recommendedDetail;

  // 히스토리 (메모리 + 로컬 저장 모두)
  final List<_HistoryItem> _history = [];

  // 작업자 로그인 상태
  bool _isWorkerLoggedIn = false;
  String _loggedInWorker = '';

  List<Ingredient> get _ingredients => DataService.getIngredients();

  double get _totalRatio =>
      _mixItems.fold(0.0, (s, it) => s + (double.tryParse(it.ratioCtrl.text) ?? 0));

  // 포장중량 카테고리별 허용 용기
  List<String> get _allowedPackagingTypes {
    switch (_weightCat) {
      case WeightCategory.under100:
        return ['vinyl', 'container', 'sample'];
      case WeightCategory.over100:
        return ['vinyl', 'container'];
      case WeightCategory.bulk:
        return ['vinyl'];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    // 저장된 레시피를 히스토리로 로드 (최근 20개) - 로그인한 경우 본인 기록만
    final String? workerFilter = _isWorkerLoggedIn ? _loggedInWorker : null;
    final recipes = DataService.getRecipes(workerName: workerFilter);
    final loaded = recipes.take(20).map((r) {
      final ingLabel = r.items.map((it) => it.ingredientName).join('+');
      final catLabel = _catLabelFromStr(r.weightCategory);
      final pkgLabel = _pkgLabelFromStr(r.packagingType);
      return _HistoryItem(
        recipeId: r.id,
        label: '$ingLabel | $catLabel | $pkgLabel',
        price: r.calculatedPrice,
        detail: '',
        weightCategory: r.weightCategory,
        time: r.createdAt,
        workerName: r.workerName,
        isMixed: !r.isSingleIngredient,
        ingredientsLabel: ingLabel,
        weightG: r.packagingWeight,
        bulkMoqKg: r.bulkMoqKg,
      );
    }).toList();
    setState(() {
      _history.clear();
      _history.addAll(loaded);
    });
  }

  String _catLabelFromStr(String cat) {
    switch (cat) {
      case 'over100':
        return '100g이상';
      case 'bulk':
        return '벌크';
      default:
        return '100g이하';
    }
  }

  String _pkgLabelFromStr(String pkg) {
    switch (pkg) {
      case 'container':
        return '통';
      case 'sample':
        return '샘플';
      default:
        return '비닐';
    }
  }

  void _onWeightCatChanged(WeightCategory cat) {
    setState(() {
      _weightCat = cat;
      _weightCtrl.clear();
      _weightError = null;
      _result = null;
      if (!_allowedPackagingTypes.contains(_packagingType)) {
        _packagingType = _allowedPackagingTypes.first;
      }
    });
  }

  String? _validateWeight() {
    final raw = _weightCtrl.text.trim();
    if (raw.isEmpty) return '중량을 입력해주세요.';
    final v = double.tryParse(raw);
    if (v == null) return '숫자만 입력해주세요.';
    switch (_weightCat) {
      case WeightCategory.under100:
        if (v < 1 || v > 100) return '1~100g 범위로 입력해주세요.';
        break;
      case WeightCategory.over100:
        if (v < 100 || v > 999) return '100~999g 범위로 입력해주세요.';
        break;
      case WeightCategory.bulk:
        if (v <= 0) return '0 초과 값을 입력해주세요.';
        break;
    }
    return null;
  }

  void _calculate() {
    if (_workerCtrl.text.trim().isEmpty) {
      _showSnack('작업자 이름을 입력해주세요.');
      return;
    }

    final weightErr = _validateWeight();
    setState(() => _weightError = weightErr);
    if (weightErr != null) return;

    final rawWeight = double.parse(_weightCtrl.text.trim());
    final weightG =
        _weightCat == WeightCategory.bulk ? rawWeight * 1000 : rawWeight;

    final wc = DataService.getWorkCost();
    List<RecipeItem> items;

    if (!_isMixed) {
      if (_selectedIngredient == null) {
        _showSnack('원료를 선택해주세요.');
        return;
      }
      items = [
        RecipeItem(
          ingredientId: _selectedIngredient!.id,
          ingredientName: _selectedIngredient!.name,
          ratio: 100,
        )
      ];
    } else {
      if (_mixItems.isEmpty) {
        _showSnack('원료를 추가해주세요.');
        return;
      }
      if (_mixItems.any((it) => it.ingredient == null)) {
        _showSnack('모든 원료를 선택해주세요.');
        return;
      }
      final total = _totalRatio;
      if ((total - 100).abs() > 0.5) {
        _showSnack(
            '원료 비율 합계가 100%가 되어야 합니다. (현재: ${total.toStringAsFixed(1)}%)');
        return;
      }
      items = _mixItems
          .map((it) => RecipeItem(
                ingredientId: it.ingredient!.id,
                ingredientName: it.ingredient!.name,
                ratio: double.tryParse(it.ratioCtrl.text) ?? 0,
              ))
          .toList();
    }

    // 벌크의 경우: 대표 원물의 bulkWeightKg 사용 (MOQ)
    double actualWeightG = weightG;
    double bulkMoqKg = 10.0;
    if (_weightCat == WeightCategory.bulk) {
      if (!_isMixed && _selectedIngredient != null) {
        bulkMoqKg = _selectedIngredient!.bulkWeightKg;
      } else if (_isMixed && _mixItems.isNotEmpty) {
        final mainIng = _ingredients
            .where((i) => i.id == _mixItems.first.ingredient?.id)
            .firstOrNull;
        if (mainIng != null) bulkMoqKg = mainIng.bulkWeightKg;
      }
      // 벌크: 입력값(kg) 그대로 사용, MOQ 단위 안내만
      actualWeightG = rawWeight * 1000;
    }

    // 포장 선택
    final pkgList = DataService.getPackagings()
        .where((p) => p.category == _packagingType)
        .toList();
    if (pkgList.isEmpty) {
      _showSnack('해당 포장 유형이 설정되어 있지 않습니다. 관리자에게 문의하세요.');
      return;
    }

    Packaging pkg = pkgList.first;
    String? recommended;
    String? detail;

    if (_packagingType == 'container') {
      final estimatedVol = actualWeightG * 9;
      final containers = pkgList.where((p) => p.volumeCC != null).toList()
        ..sort((a, b) => a.volumeCC!.compareTo(b.volumeCC!));
      final fit =
          containers.where((p) => p.volumeCC! >= estimatedVol).toList();
      if (fit.isNotEmpty) {
        pkg = fit.first;
        recommended = pkg.name;
        detail =
            '${actualWeightG.toStringAsFixed(0)}g 기준 약 ${estimatedVol.toStringAsFixed(0)}cc 추정 → ${pkg.name} 권장';
      } else if (containers.isNotEmpty) {
        pkg = containers.last;
        recommended = pkg.name;
        detail = '${pkg.name} (분할 포장 필요할 수 있음)';
      }
    } else {
      recommended = pkg.name;
      if (_weightCat == WeightCategory.bulk) {
        detail =
            '벌크 비닐포장 (${rawWeight.toStringAsFixed(0)}kg, MOQ: ${bulkMoqKg.toStringAsFixed(0)}kg 단위)';
      } else {
        detail = '${pkg.name} 적용';
      }
    }

    final result = CostCalculator.calculate(
      items: items,
      allIngredients: _ingredients,
      wc: wc,
      packaging: pkg,
      packagingWeightG: actualWeightG,
      isMixed: _isMixed,
    );

    // 라벨 생성
    final ingLabel = _isMixed
        ? _mixItems
            .map((it) => '${it.ingredient?.name}(${it.ratioCtrl.text}%)')
            .join('+')
        : _selectedIngredient!.name;
    final catLabel = _weightCat == WeightCategory.under100
        ? '${rawWeight.toStringAsFixed(0)}g(100g이하)'
        : _weightCat == WeightCategory.over100
            ? '${rawWeight.toStringAsFixed(0)}g(100g이상)'
            : '벌크${rawWeight.toStringAsFixed(0)}kg(MOQ:${bulkMoqKg.toStringAsFixed(0)}kg)';
    final pkgLabel = _packagingType == 'vinyl'
        ? '비닐'
        : _packagingType == 'container'
            ? '통'
            : '샘플';

    // 레시피 저장
    final recipe = Recipe(
      id: const Uuid().v4(),
      name: '$ingLabel $catLabel $pkgLabel',
      items: items,
      packagingId: pkg.id,
      packagingWeight: actualWeightG,
      packagingType: _packagingType,
      calculatedPrice: result.unitPricePerPack,
      workerName: _workerCtrl.text.trim(),
      weightCategory: _weightCat.name,
      bulkMoqKg: bulkMoqKg,
    );
    DataService.saveRecipe(recipe);

    // 히스토리 맨 앞에 추가
    final histItem = _HistoryItem(
      recipeId: recipe.id,
      label: '$ingLabel | $catLabel | $pkgLabel',
      price: result.unitPricePerPack,
      detail: detail ?? '',
      weightCategory: _weightCat.name,
      time: DateTime.now(),
      workerName: _workerCtrl.text.trim(),
      isMixed: _isMixed,
      ingredientsLabel: ingLabel,
      weightG: actualWeightG,
      bulkMoqKg: bulkMoqKg,
    );

    setState(() {
      _history.insert(0, histItem);
      _result = result;
      _recommendedContainer = recommended;
      _recommendedDetail = detail;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // 히스토리 삭제
  Future<void> _deleteHistory(int index) async {
    final item = _history[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 견적 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DataService.deleteRecipe(item.recipeId);
      setState(() => _history.removeAt(index));
    }
  }

  // 히스토리 공유 (개별)
  void _shareHistory(_HistoryItem item) {
    _showShareDialog(item.shareText, item.label);
  }

  // 전체 히스토리 공유
  void _shareAllHistory() {
    if (_history.isEmpty) return;
    final buf = StringBuffer();
    buf.writeln('[ 펫신드룸 전체 견적 이력 ]');
    buf.writeln('═══════════════════════');
    for (int i = 0; i < _history.length; i++) {
      buf.writeln('\n#${_history.length - i} ${_history[i].label}');
      buf.writeln('  예상 단가: ${Fmt.won(_history[i].price)}');
      if (_history[i].weightCategory == 'bulk') {
        buf.writeln(
            '  벌크 MOQ: ${_history[i].bulkMoqKg.toStringAsFixed(0)}kg 단위');
      }
      if (_history[i].workerName.isNotEmpty) {
        buf.writeln('  작업자: ${_history[i].workerName}');
      }
      buf.writeln('  일시: ${Fmt.datetime(_history[i].time)}');
    }
    buf.writeln('\n═══════════════════════');
    buf.writeln('※ 예상 단가이며 확정 견적은 펫신드룸으로 문의해 주세요.');
    _showShareDialog(buf.toString(), '전체 견적 이력 (${_history.length}건)');
  }

  void _showShareDialog(String text, String title) {
    showDialog(
      context: context,
      builder: (_) => _ShareDialog(shareText: text, title: title),
    );
  }

  // 다시 계산
  void _resetForm() {
    setState(() {
      _result = null;
      _selectedIngredient = null;
      for (final m in _mixItems) {
        m.ratioCtrl.dispose();
      }
      _mixItems.clear();
      _weightCtrl.clear();
      _weightError = null;
      _packagingType = 'vinyl';
      _isMixed = false;
      _weightCat = WeightCategory.under100;
      _recommendedContainer = null;
      _recommendedDetail = null;
    });
  }

  void _showWorkerLoginDialog() {
    final nameCtrl = TextEditingController(text: _workerCtrl.text.trim());
    final pinCtrl = TextEditingController();
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('작업자 로그인', style: AppText.heading3),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('이름과 PIN 번호로 로그인하면\n본인 견적 이력만 확인할 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '작업자 이름',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN 번호',
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                  isDense: true,
                ),
                onSubmitted: (_) async {
                  final name = nameCtrl.text.trim();
                  final pin = pinCtrl.text.trim();
                  if (name.isEmpty || pin.isEmpty) return;
                  if (DataService.checkWorkerLogin(name, pin) || DataService.checkLogin(name, pin)) {
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    setState(() {
                      _isWorkerLoggedIn = true;
                      _loggedInWorker = name;
                      _workerCtrl.text = name;
                    });
                    _loadHistory();
                  } else {
                    setDlgState(() => errorMsg = '이름 또는 PIN이 올바르지 않습니다.');
                  }
                },
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(errorMsg!, style: const TextStyle(fontSize: 11, color: AppTheme.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.isEmpty || pin.isEmpty) {
                  setDlgState(() => errorMsg = '이름과 PIN을 모두 입력하세요');
                  return;
                }
                if (DataService.checkWorkerLogin(name, pin) || DataService.checkLogin(name, pin)) {
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  setState(() {
                    _isWorkerLoggedIn = true;
                    _loggedInWorker = name;
                    _workerCtrl.text = name;
                  });
                  _loadHistory();
                } else {
                  setDlgState(() => errorMsg = '이름 또는 PIN이 올바르지 않습니다.');
                }
              },
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _workerCtrl.dispose();
    _weightCtrl.dispose();
    for (final m in _mixItems) {
      m.ratioCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 32, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(),
                    const SizedBox(height: 20),

                    // 작업자 입력 + 로그인
                    _StepCard(
                      step: '0',
                      title: '작업자',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_isWorkerLoggedIn) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _workerCtrl,
                                    decoration: const InputDecoration(
                                      hintText: '작업자 이름',
                                      prefixIcon: Icon(Icons.person_outline, size: 18),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _showWorkerLoginDialog(),
                                  icon: const Icon(Icons.login, size: 14),
                                  label: const Text('로그인', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_loggedInWorker, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                        const Text('로그인됨 · 본인 견적 이력만 표시', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isWorkerLoggedIn = false;
                                        _loggedInWorker = '';
                                        _workerCtrl.clear();
                                      });
                                      _loadHistory();
                                    },
                                    child: const Text('로그아웃', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // STEP 1
                    _StepCard(
                      step: '1',
                      title: '원료 유형 선택',
                      child: _TypeToggle(
                          isMixed: _isMixed,
                          onChanged: (v) => setState(
                              () { _isMixed = v; _result = null; })),
                    ),
                    const SizedBox(height: 10),

                    // STEP 2
                    _StepCard(
                      step: '2',
                      title: _isMixed
                          ? '혼합 원료 선택 (비율 합계 = 100%)'
                          : '단일 원료 선택',
                      child: _isMixed
                          ? _MixedPicker(
                              ingredients: _ingredients,
                              mixItems: _mixItems,
                              totalRatio: _totalRatio,
                              onChanged: () =>
                                  setState(() => _result = null),
                            )
                          : _SinglePicker(
                              ingredients: _ingredients,
                              selected: _selectedIngredient,
                              onChanged: (ing) => setState(() {
                                _selectedIngredient = ing;
                                _result = null;
                              }),
                            ),
                    ),
                    const SizedBox(height: 10),

                    // STEP 3: 포장중량
                    _StepCard(
                      step: '3',
                      title: '포장 중량 선택',
                      child: _WeightSection(
                        category: _weightCat,
                        ctrl: _weightCtrl,
                        error: _weightError,
                        onCategoryChanged: _onWeightCatChanged,
                        onChanged: () => setState(
                            () { _weightError = null; _result = null; }),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // STEP 4: 용기 종류
                    _StepCard(
                      step: '4',
                      title: '용기 종류 선택',
                      child: _PackagingPicker(
                        selected: _packagingType,
                        allowed: _allowedPackagingTypes,
                        weightCat: _weightCat,
                        onChanged: (v) => setState(() {
                          _packagingType = v;
                          _result = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: _calculate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('견적 계산하기'),
                    ),

                    // 최신 결과
                    if (_result != null) ...[
                      const SizedBox(height: 18),
                      _ResultCard(
                        result: _result!,
                        recommendedContainer: _recommendedContainer,
                        recommendedDetail: _recommendedDetail,
                        weightCat: _weightCat,
                        weightInput: _weightCtrl.text,
                        packagingType: _packagingType,
                        isMixed: _isMixed,
                        itemsLabel: _isMixed
                            ? _mixItems
                                .map((it) =>
                                    '${it.ingredient?.name ?? ''}(${it.ratioCtrl.text}%)')
                                .join('+')
                            : _selectedIngredient?.name ?? '',
                        onReset: _resetForm,
                        bulkMoqKg: _weightCat == WeightCategory.bulk
                            ? (!_isMixed && _selectedIngredient != null
                                ? _selectedIngredient!.bulkWeightKg
                                : 10.0)
                            : null,
                      ),
                    ],

                    // 히스토리
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _HistoryHeader(
                        count: _history.length,
                        onShareAll: _shareAllHistory,
                      ),
                      const SizedBox(height: 8),
                      ..._history.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HistoryCard(
                              item: e.value,
                              index: _history.length - e.key,
                              onDelete: () => _deleteHistory(e.key),
                              onShare: () => _shareHistory(e.value),
                            ),
                          )),
                    ],

                    const SizedBox(height: 40),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/admin/login'),
                        child: const Text('관리자 로그인',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 공유 다이얼로그 (이메일 / 클립보드)
// ══════════════════════════════════════════════════
class _ShareDialog extends StatelessWidget {
  final String shareText;
  final String title;
  const _ShareDialog({required this.shareText, required this.title});

  void _copyToClipboard(BuildContext context) {
    // Web: clipboard API
    if (kIsWeb) {
      html.window.navigator.clipboard?.writeText(shareText);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('클립보드에 복사되었습니다.'), behavior: SnackBarBehavior.floating),
    );
  }

  void _openEmail(BuildContext context) {
    final subject = Uri.encodeComponent('펫신드룸 단가 견적');
    final body = Uri.encodeComponent(shareText);
    final url = 'mailto:?subject=$subject&body=$body';
    if (kIsWeb) {
      html.window.open(url, '_blank');
    }
    Navigator.pop(context);
  }

  void _openKakao(BuildContext context) {
    // 카카오 공유는 SDK 연동 필요. 웹에서는 클립보드 복사 후 안내
    _copyToClipboard(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('텍스트가 복사되었습니다. 카카오톡에 붙여넣기 해주세요.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.share_outlined,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: AppText.heading3,
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const Divider(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  child: Text(shareText,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          height: 1.6)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('공유 방법 선택',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _ShareBtn(
                    icon: Icons.copy,
                    label: '클립보드 복사',
                    color: AppTheme.primary,
                    onTap: () => _copyToClipboard(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShareBtn(
                    icon: Icons.email_outlined,
                    label: '이메일 전송',
                    color: AppTheme.info,
                    onTap: () => _openEmail(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShareBtn(
                    icon: Icons.chat_bubble_outline,
                    label: '카카오톡',
                    color: const Color(0xFFF9E000),
                    textColor: const Color(0xFF3A1D00),
                    onTap: () => _openKakao(context),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;
  const _ShareBtn(
      {required this.icon,
      required this.label,
      required this.color,
      this.textColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(icon, size: 20, color: textColor ?? color),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: textColor ?? color,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 헤더
// ══════════════════════════════════════════════════
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10)),
              child:
                  const Icon(Icons.pets, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('펫신드룸 단가 계산기',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('동결건조 간식 견적 계산',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(8)),
          child: const Text(
            '원료·포장중량·용기를 선택하면 예상 단가를 계산해드립니다.\n실제 단가는 샘플 가공 후 확정됩니다.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.primary, height: 1.5),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// Step Card 래퍼
// ══════════════════════════════════════════════════
class _StepCard extends StatelessWidget {
  final String step, title;
  final Widget child;
  const _StepCard(
      {required this.step, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(step,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppText.heading3)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 단미/혼합 토글
// ══════════════════════════════════════════════════
class _TypeToggle extends StatelessWidget {
  final bool isMixed;
  final ValueChanged<bool> onChanged;
  const _TypeToggle({required this.isMixed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _TBtn(
                label: '단일 원료',
                sub: '원료 1가지',
                selected: !isMixed,
                onTap: () => onChanged(false))),
        const SizedBox(width: 10),
        Expanded(
            child: _TBtn(
                label: '혼합 원료',
                sub: '2가지 이상',
                selected: isMixed,
                onTap: () => onChanged(true))),
      ],
    );
  }
}

class _TBtn extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _TBtn(
      {required this.label,
      required this.sub,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? Colors.white : AppTheme.textPrimary)),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? Colors.white70
                        : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 단일 원료 선택
// ══════════════════════════════════════════════════
class _SinglePicker extends StatelessWidget {
  final List<Ingredient> ingredients;
  final Ingredient? selected;
  final ValueChanged<Ingredient?> onChanged;
  const _SinglePicker(
      {required this.ingredients,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Ingredient>(
      initialValue: selected,
      hint: const Text('원료를 선택해주세요'),
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: ingredients
          .map((ing) => DropdownMenuItem(
                value: ing,
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: ing.type == 'raw'
                                ? AppTheme.primary
                                : AppTheme.warning,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(ing.name,
                            style: const TextStyle(fontSize: 13))),
                    Text(ing.typeName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ══════════════════════════════════════════════════
// 혼합 원료 선택
// ══════════════════════════════════════════════════
class _MixItem {
  Ingredient? ingredient;
  final ratioCtrl = TextEditingController();
}

class _MixedPicker extends StatelessWidget {
  final List<Ingredient> ingredients;
  final List<_MixItem> mixItems;
  final double totalRatio;
  final VoidCallback onChanged;
  const _MixedPicker(
      {required this.ingredients,
      required this.mixItems,
      required this.totalRatio,
      required this.onChanged});

  void _add() {
    mixItems.add(_MixItem());
    onChanged();
  }

  void _remove(int i) {
    mixItems[i].ratioCtrl.dispose();
    mixItems.removeAt(i);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isOver = totalRatio > 100.01;
    final isOk = (totalRatio - 100).abs() <= 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (totalRatio / 100).clamp(0, 1),
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation(isOver
                      ? AppTheme.danger
                      : isOk
                          ? AppTheme.primary
                          : AppTheme.warning),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${totalRatio.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOver
                        ? AppTheme.danger
                        : isOk
                            ? AppTheme.primary
                            : AppTheme.warning)),
          ],
        ),
        if (!isOk)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              totalRatio < 100
                  ? '${(100 - totalRatio).toStringAsFixed(1)}% 더 추가해야 합니다.'
                  : '${(totalRatio - 100).toStringAsFixed(1)}% 초과입니다.',
              style: TextStyle(
                  fontSize: 11,
                  color: isOver ? AppTheme.danger : AppTheme.warning),
            ),
          ),
        const SizedBox(height: 10),
        ...mixItems.asMap().entries.map((e) => _MixRow(
            index: e.key,
            item: e.value,
            ingredients: ingredients,
            onRemove: () => _remove(e.key),
            onChanged: onChanged)),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('원료 추가'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
        ),
      ],
    );
  }
}

class _MixRow extends StatelessWidget {
  final int index;
  final _MixItem item;
  final List<Ingredient> ingredients;
  final VoidCallback onRemove, onChanged;
  const _MixRow(
      {required this.index,
      required this.item,
      required this.ingredients,
      required this.onRemove,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<Ingredient>(
              initialValue: item.ingredient,
              hint: const Text('원료 선택',
                  style: TextStyle(fontSize: 12)),
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: ingredients
                  .map((ing) => DropdownMenuItem(
                      value: ing,
                      child: Text(ing.name,
                          style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) {
                item.ingredient = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.ratioCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  suffixText: '%', isDense: true, hintText: '0'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppTheme.danger),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 포장 중량 섹션
// ══════════════════════════════════════════════════
class _WeightSection extends StatelessWidget {
  final WeightCategory category;
  final TextEditingController ctrl;
  final String? error;
  final ValueChanged<WeightCategory> onCategoryChanged;
  final VoidCallback onChanged;
  const _WeightSection(
      {required this.category,
      required this.ctrl,
      this.error,
      required this.onCategoryChanged,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String hint = '';
    String helper = '';
    String suffix = 'g';
    switch (category) {
      case WeightCategory.under100:
        hint = '1~100';
        helper = '1g 이상 100g 이하로 입력';
        break;
      case WeightCategory.over100:
        hint = '100~999';
        helper = '100g 이상 999g 이하로 입력';
        break;
      case WeightCategory.bulk:
        hint = '예: 10';
        helper = '벌크 KG 입력 (MOQ는 원물 설정 기준)';
        suffix = 'kg';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: _WCatBtn(
                    label: '100g 이하',
                    value: WeightCategory.under100,
                    current: category,
                    onTap: onCategoryChanged)),
            const SizedBox(width: 8),
            Expanded(
                child: _WCatBtn(
                    label: '100g 이상',
                    value: WeightCategory.over100,
                    current: category,
                    onTap: onCategoryChanged)),
            const SizedBox(width: 8),
            Expanded(
                child: _WCatBtn(
                    label: '벌크견적\n(KG)',
                    value: WeightCategory.bulk,
                    current: category,
                    onTap: onCategoryChanged)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            helperText: helper,
            errorText: error,
          ),
        ),
        if (category == WeightCategory.bulk)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.info_outline, size: 13, color: AppTheme.info),
              SizedBox(width: 4),
              Expanded(
                  child: Text(
                '벌크 단가는 1kg 기준이며, MOQ(최소주문단위)는 원물별 설정값 기준입니다.',
                style: TextStyle(fontSize: 11, color: AppTheme.info),
              )),
            ]),
          ),
      ],
    );
  }
}

class _WCatBtn extends StatelessWidget {
  final String label;
  final WeightCategory value, current;
  final ValueChanged<WeightCategory> onTap;
  const _WCatBtn(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? AppTheme.primary : AppTheme.border,
              width: sel ? 1.5 : 1),
        ),
        child: Center(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: sel ? Colors.white : AppTheme.textSecondary,
                    fontWeight: sel
                        ? FontWeight.w600
                        : FontWeight.normal))),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 용기 선택
// ══════════════════════════════════════════════════
class _PackagingPicker extends StatelessWidget {
  final String selected;
  final List<String> allowed;
  final WeightCategory weightCat;
  final ValueChanged<String> onChanged;
  const _PackagingPicker(
      {required this.selected,
      required this.allowed,
      required this.weightCat,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final allTypes = [
      ('vinyl', '비닐 포장', Icons.inventory_outlined),
      ('container', '통 포장', Icons.circle_outlined),
      ('sample', '샘플 포장', Icons.science_outlined),
    ];
    final available =
        allTypes.where((t) => allowed.contains(t.$1)).toList();

    String helperText = '';
    if (weightCat == WeightCategory.under100) {
      helperText = '100g 이하: 비닐·통·샘플 모두 가능';
    }
    if (weightCat == WeightCategory.over100) {
      helperText = '100g 이상: 비닐·통 포장 가능';
    }
    if (weightCat == WeightCategory.bulk) {
      helperText = '벌크: 비닐 포장만 가능';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: available
              .map((t) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: available.last == t ? 0 : 8),
                      child: _PkgBtn(
                          value: t.$1,
                          label: t.$2,
                          icon: t.$3,
                          selected: selected,
                          onTap: onChanged),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        Text(helperText, style: AppText.bodySmall),
      ],
    );
  }
}

class _PkgBtn extends StatelessWidget {
  final String value, label, selected;
  final IconData icon;
  final ValueChanged<String> onTap;
  const _PkgBtn(
      {required this.value,
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? AppTheme.primary : AppTheme.border,
              width: sel ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon,
              size: 22,
              color: sel ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: sel
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  fontWeight: sel
                      ? FontWeight.w600
                      : FontWeight.normal),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 결과 카드 (예상단가만 표시)
// ══════════════════════════════════════════════════
class _ResultCard extends StatelessWidget {
  final CostResult result;
  final String? recommendedContainer, recommendedDetail;
  final WeightCategory weightCat;
  final String weightInput, packagingType, itemsLabel;
  final bool isMixed;
  final VoidCallback onReset;
  final double? bulkMoqKg;

  const _ResultCard({
    required this.result,
    this.recommendedContainer,
    this.recommendedDetail,
    required this.weightCat,
    required this.weightInput,
    required this.packagingType,
    required this.isMixed,
    required this.itemsLabel,
    required this.onReset,
    this.bulkMoqKg,
  });

  static void _showFormulaDialog(BuildContext context, CostResult result) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('원가 계산식 상세', style: AppText.heading3)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(_),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (result.detailedFormula.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(result.detailedFormula,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.5)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text('단계별 계산', style: AppText.label),
                      const SizedBox(height: 8),
                      ...result.formulaSteps.asMap().entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.6, color: AppTheme.textPrimary)),
                      )),
                      const Divider(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('최종 단가 (kg당)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(Fmt.won(result.unitPricePerKg) + '/kg',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '※ 본 계산식은 예상 수치이며, 실제 수율은\n샘플 가공 후 최종 확정됩니다.',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catLabel = weightCat == WeightCategory.under100
        ? '${weightInput}g (100g이하)'
        : weightCat == WeightCategory.over100
            ? '${weightInput}g (100g이상)'
            : '벌크 ${weightInput}kg';
    final pkgLabel = packagingType == 'vinyl'
        ? '비닐포장'
        : packagingType == 'container'
            ? '통포장'
            : '샘플포장';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('견적 계산 결과', style: AppText.heading3)),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('추가 계산',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(6)),
            child: Text(
              '${isMixed ? "혼합" : "단미"} | $itemsLabel | $catLabel | $pkgLabel',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (recommendedDetail != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppTheme.info),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('추천: $recommendedDetail',
                      style:
                          const TextStyle(fontSize: 11, color: AppTheme.info))),
            ]),
          ],
          const Divider(height: 24),
          // 예상 단가 + 계산식 클릭
          GestureDetector(
            onTap: () => _showFormulaDialog(context, result),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('예상 단가 (개당)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.calculate_outlined, size: 11, color: AppTheme.primary),
                        const SizedBox(width: 3),
                        const Text('계산식 보기', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                      ]),
                    ],
                  ),
                  Text(Fmt.won(result.unitPricePerPack),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                ],
              ),
            ),
          ),
          if (weightCat == WeightCategory.bulk) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showFormulaDialog(context, result),
              child: Text('벌크 kg당 단가: ${Fmt.won(result.unitPricePerKg)}/kg ▶ 계산식',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, decoration: TextDecoration.underline)),
            ),
            if (bulkMoqKg != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_outlined,
                        size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                      'MOQ(최소주문단위): ${bulkMoqKg!.toStringAsFixed(0)}kg 이상 주문 가능합니다.',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(8)),
            child: const Text(
              '※ 본 견적은 예상 단가입니다. 실제 수율은 샘플 가공 후 확정되며,\n수량·원자재 시세에 따라 달라질 수 있습니다.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 히스토리 헤더
// ══════════════════════════════════════════════════
class _HistoryHeader extends StatelessWidget {
  final int count;
  final VoidCallback onShareAll;
  const _HistoryHeader({required this.count, required this.onShareAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.history, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text('이전 견적 히스토리 ($count건)', style: AppText.heading3),
        const Spacer(),
        TextButton.icon(
          onPressed: onShareAll,
          icon: const Icon(Icons.share_outlined, size: 14),
          label: const Text('전체 공유', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: AppTheme.info),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// 히스토리 카드
// ══════════════════════════════════════════════════
class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  const _HistoryCard(
      {required this.item,
      required this.index,
      required this.onDelete,
      required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: Text('$index',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis),
                if (item.workerName.isNotEmpty)
                  Text('작업자: ${item.workerName}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.info)),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 10, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text(Fmt.datetime(item.time), style: AppText.bodySmall),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.won(item.price),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 공유 버튼
                  GestureDetector(
                    onTap: onShare,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.share_outlined,
                          size: 15, color: AppTheme.info),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // 삭제 버튼
                  GestureDetector(
                    onTap: onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 15, color: AppTheme.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
