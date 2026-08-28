import math
import numpy as np
import time

start_time = time.time()

def calculate_x(a, x0, n):
    x_values = [x0]
    for i in range(n):
        
#   x_next =  math.sin(a * math.pi * x_values[i] * (1 - x_values[i]))   #1
#   x_next =  math.sin(a * math.sin(math.pi * x_values[i])    #2
#   x_next =  
#   x_next = (math.sin(a * math.sin(math.pi * x_values[i])) + math.sin(a * math.pi * x_values[i] * (1 - x_values[i])))/2 #proposed1
#   x_next = (math.sin(a * math.sin(math.pi * x_values[i])) + math.sin(a * math.pi * x_values[i] * (1 - x_values[i])))%1 #
#   x_next = (math.sin(a * math.sin(math.pi * x_values[i])) + math.sin(a * math.pi * x_values[i] * (1 - x_values[i])))%1 #
        x_next =  (math.sin(a * math.sin(math.pi * x_values[i])) + math.sin(a * math.pi * x_values[i] * (1 - x_values[i]))) #proposed1
        x_values.append(x_next)
    return x_values

def ddt(S, n, m):
    D = [[0] * (2 ** m) for _ in range(2 ** n)]
    for alpha in range(2 ** n):
        for x in range(2 ** n):
            beta = S[x] ^ S[x ^ alpha]
            D[alpha][beta] += 1
    return D

def second_largest_ddt_value(S, n, m):
    D = ddt(S, n, m)
    max_values = []

    for alpha in range(2 ** n):
        for beta in range(2 ** m):
            max_values.append(D[alpha][beta])

    max_values = sorted(set(max_values), reverse=True)
    second_max = 0

    for value in max_values:
        if value != 16:  # Loại trừ giá trị 16
            second_max = value
            break

    return second_max

def hamming_distance(x, y):
    # XOR hai giá trị đầu vào và đếm số bit 1 trong kết quả
    xor_result = x ^ y
    distance = bin(xor_result).count('1')
    return distance

def average_hamming_distance(sbox):
    total_distance = 0
    num_inputs = 16

    # Duyệt qua tất cả cặp đầu vào và đầu ra
    for input_value in range(16):
        output_value = sbox[input_value]
        distance = hamming_distance(input_value, output_value)
        total_distance += distance

    # Tính khoảng cách Hamming trung bình
    average_distance = total_distance / num_inputs
    return average_distance


def calculate_walsh_spectrum(f):
    n = 4  # Số biến
    N = 2 ** n  # Số lượng giá trị x và w

    # Tạo danh sách các giá trị của hàm f từ chuỗi bit
    f_values = [int(bit) for bit in f]

    # Tính ma trận y = f(x) xor (w.x)
    y_matrix = np.zeros((N, N), dtype=int)
    for x in range(N):
        for w in range(N):
            wx = sum(int(xi) & int(wi) for xi, wi in zip(bin(x)[2:].zfill(n), bin(w)[2:].zfill(n)))
            y_matrix[x, w] = f_values[x] ^ wx

    # Tính ma trận bằng (trừ 1) mũ y
    matrix = (-1) ** y_matrix

    # Tính ma trận S
    walsh_spectrum = np.sum(matrix, axis=0)

    return walsh_spectrum

def calculate_nonlinearity(walsh_spectrum):
    max_abs_walsh = max(abs(val) for val in walsh_spectrum)
    nonlinearity = 8 - max_abs_walsh / 2
    return nonlinearity

def calculate_sac(f):
    n = 4  # Số biến
    N = 2 ** n  # Số lượng giá trị x

    # Tạo danh sách các giá trị của hàm f từ chuỗi bit
    f_values = [int(bit) for bit in f]

    sac_matrix = np.zeros((N, 4), dtype=int)
    for x in range(N):
        for i, t in enumerate([0b0001, 0b0010, 0b0100, 0b1000], start=1):
            xor_x_xort = f_values[x] ^ f_values[x ^ t]
            xor_x_x = f_values[x] ^ f_values[x]
            sac_matrix[x, i - 1] = xor_x_xort - xor_x_x

    return sac_matrix

def calculate_sac_bit_sum(sac_matrix):
    bit_sums = np.sum(sac_matrix == 1, axis=0)
    return bit_sums

def hamming_weight(x):
    # Đếm số bit 1 trong giá trị x
    weight = bin(x).count('1')
    return weight

def calculate_branch_number(sbox):
    n = 4  # Số bit đầu vào và đầu ra
    branch_number = float("inf")  # Khởi tạo branch number với giá trị vô cùng lớn

    # Duyệt qua tất cả cặp giá trị đầu vào x và y
    for x in range(2 ** n):
        for y in range(2 ** n):
            if x != y:  # Loại trừ trường hợp x = y
                xor_hw = hamming_weight(x ^ y)
                sbox_x_hw = hamming_weight(sbox[x])
                sbox_y_hw = hamming_weight(sbox[y])
                sum_hw = sbox_x_hw + sbox_y_hw

                branch_value = xor_hw + sum_hw

                if branch_value < branch_number:
                    branch_number = branch_value

    return branch_number
def write_to_file(file_path, content):
    with open(file_path, 'w', encoding='utf-8') as file:
        file.write(content)


# Tính LAP dựa vào ma trận LAT
def dot(U, V):
    W = U & V
    dot_result = 0
    while W != 0:
        dot_result ^= W & 1
        W >>= 1 
    return dot_result

def bias_integer(S, alpha, beta, n):
    e = 0
    for x in range(2**n):
        if dot(alpha, x) ^ dot(beta, S[x]) == 0:
            e += 1
    return e - 2 ** (n - 1)

def lat(S, n, m):
    L = [[0] * (2 ** m) for _ in range(2 ** n)]
    for alpha in range(2 ** n):
        for beta in range(2 ** m):
            L[alpha][beta] = bias_integer(S, alpha, beta, n)
    return L

def print_lat(S, n, m):
    L = lat(S, n, m)
    for alpha in range(2 ** n):
        for beta in range(2 ** m):
            e = str(L[alpha][beta]).rjust(2)
            print(e, end='')
        print()
def LAT(S, n, m):
    L = lat(S, n, m)
    all_values = [abs(L[alpha][beta]) for alpha in range(2 ** n) for beta in range(2 ** m)]
    all_values.sort(reverse=True)
    second_largest_abs_value = all_values[1]
    return second_largest_abs_value

def generation(target_dap_value,target_branch_number,target_lap_value,target_hamming_distance_value):
    min_x0 = 0.1
    max_x0 = 1.0
    min_a = 1
    max_a = 1000
    step_x0 = 0.0001  # Bước nhảy là 0.0001

    valid_pairs = []

    for x0 in range(int(min_x0 * 10000), int((max_x0 + step_x0) * 10000), int(step_x0 * 10000)):
        x0 /= 10000
        for a in range(min_a, max_a + 1):
            x_values = calculate_x(a, x0, 15)
            sorted_x_indices = sorted(range(len(x_values)), key=lambda i: x_values[i], reverse=True)

            valid_indices = all(sorted_x_indices[i] != i and sorted_x_indices[i] != 15 - i for i in range(16))

            if valid_indices:
                s_box_table = sorted_x_indices
                ddt_value = second_largest_ddt_value(s_box_table, 4, 4)
                lap_value = LAT(s_box_table,4,4)
                if ddt_value <= target_dap_value and lap_value <= target_lap_value :
                    average_distance = average_hamming_distance(s_box_table)
                    if average_distance > target_hamming_distance_value:
                                          
                            branch_number = calculate_branch_number(s_box_table)
                            if branch_number == target_branch_number:
                                boolean_functions_sbox = []
                                for i in range(4):
                                    f = "".join(str((s_box_table[x] >> i) & 1) for x in range(16))
                                    boolean_functions_sbox.append(f)

                                boolean_functions_f1 = boolean_functions_sbox[0]
                                boolean_functions_f2 = boolean_functions_sbox[1]
                                boolean_functions_f3 = boolean_functions_sbox[2]
                                boolean_functions_f4 = boolean_functions_sbox[3]

                                boolean_functions_f12 = [str(int(boolean_functions_f1[j]) ^ int(boolean_functions_f2[j])) for j in range(16)]
                                boolean_functions_f13 = [str(int(boolean_functions_f1[j]) ^ int(boolean_functions_f3[j])) for j in range(16)]
                                boolean_functions_f14 = [str(int(boolean_functions_f1[j]) ^ int(boolean_functions_f4[j])) for j in range(16)]
                                boolean_functions_f23 = [str(int(boolean_functions_f2[j]) ^ int(boolean_functions_f3[j])) for j in range(16)]
                                boolean_functions_f24 = [str(int(boolean_functions_f2[j]) ^ int(boolean_functions_f4[j])) for j in range(16)]
                                boolean_functions_f34 = [str(int(boolean_functions_f3[j]) ^ int(boolean_functions_f4[j])) for j in range(16)]


                                boolean_functions_10 = [boolean_functions_f1, boolean_functions_f2, boolean_functions_f3, boolean_functions_f4,
                                                        boolean_functions_f12, boolean_functions_f13, boolean_functions_f14,
                                                        boolean_functions_f23, boolean_functions_f24, boolean_functions_f34]

                                sac_bit_sums_1_to_4 = [calculate_sac_bit_sum(calculate_sac(f)) for f in boolean_functions_10[:4]]
                                total_average_sac_bit_sums_1_to_4 = sum(np.mean(sac_bit_sum) for sac_bit_sum in sac_bit_sums_1_to_4)
                                overall_average_1_to_4 = total_average_sac_bit_sums_1_to_4 / (4 * 16)

                                sac_bit_sums_5_to_10 = [calculate_sac_bit_sum(calculate_sac(f)) for f in boolean_functions_10[4:]]
                                total_average_sac_bit_sums = sum(np.mean(sac_bit_sum) for sac_bit_sum in sac_bit_sums_5_to_10)
                                overall_average = total_average_sac_bit_sums / (6 * 16)

                                if 0.495 <= overall_average <= 0.501 and 0.495 <= overall_average_1_to_4 <= 0.501:
                                    valid_pairs.append((a, x0, s_box_table))

    return valid_pairs
target_dap_value = 4
target_lap_value =4
target_branch_number = 2
target_hamming_distance_value=2.125
valid_pairs = generation(target_dap_value,target_branch_number,target_lap_value,target_hamming_distance_value)

if valid_pairs:
    file_path = "C:\\Users\\duongphucphan\\Desktop\\Sbox\\criteria\\results\\44_sbox_result_4.txt"
    result_content = ""

    for a, x0, s_box_table in valid_pairs:
        result_content += f"Parameters: a={a}, x0={x0}\n"
        result_content += "Sbox: ["
        result_content += ", ".join(map(str, s_box_table))
        result_content += "]\n\n"

    write_to_file(file_path, result_content)
        print(f"Save results to file: {file_path}")
else:
    print(f"Not found any parameters.")
    
end_time = time.time()
total_time = end_time - start_time
print(f"Total time: {total_time} giây")
