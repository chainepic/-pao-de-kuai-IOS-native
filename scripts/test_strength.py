import json

def calculate_hand_strength(hand_str_list):
    groups = {}
    for c in hand_str_list:
        rank = c[0]
        groups[rank] = groups.get(rank, 0) + 1
        
    strength = 0
    # Bombs
    for count in groups.values():
        if count == 4:
            strength += 50
            
    # Power mapping
    # 2: 15, A: 10, K: 6, Q: 4, J: 2
    powers = {'2': 15, 'A': 10, 'K': 6, 'Q': 4, 'J': 2}
    for rank, p in powers.items():
        strength += groups.get(rank, 0) * p
        
    small_singles = 0
    for r in '3456789T':
        if groups.get(r, 0) == 1:
            small_singles += 1
            
    strength -= small_singles * 5
    return strength

def check_batch(filepath, start, end):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    target = [log for log in data['handLogs'] if start <= log.get('handNo', 0) <= end]
    
    for log in target:
        print(f"Hand #{log['handNo']}")
        for p in ['initialMe', 'initialLeft', 'initialRight']:
            hand = log[p]
            s = calculate_hand_strength(hand)
            print(f"  {p[7:]}: Strength = {s}")

if __name__ == '__main__':
    import sys
    check_batch(sys.argv[1], 21, 40)
