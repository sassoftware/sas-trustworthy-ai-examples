import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, MinMaxScaler, OneHotEncoder, OrdinalEncoder
from sklearn.feature_selection import SelectKBest, f_classif, mutual_info_classif, r_regression, f_regression

def load_data(file_path):
    """Load dataset from CSV file."""
    return pd.read_csv(file_path)

def handle_missing_values(df, strategy='remove', columns=None):
    """
    Handle missing values using specified strategy.
    Strategies: 'remove' (drop rows), 'mean', or 'median'
    """
    if columns is None:
        columns = df.columns

    if strategy == 'remove':
        return df.dropna(subset=columns)
    elif strategy == 'mean' or strategy == 'median':
        for col in columns:
            if df[col].isnull().sum() > 0:
                if pd.api.types.is_numeric_dtype(df[col]):
                    if strategy == 'mean':
                        fill_val = df[col].mean()
                    elif strategy == 'median':
                        fill_val = df[col].median()
                else:
                    fill_val = df[col].mode()[0]
                
                df[col] = df[col].fillna(fill_val)
    
    return df

def detect_column_types(df):
    """Automatically detect column types (categorical or numerical)."""
    col_types = {}

    for col in df.columns:
        if pd.api.types.is_numeric_dtype(df[col]):
            if df[col].nunique() <= 0.05 * len(df) and df[col].nunique() < 20:
                col_types[col] = 'categorical'
            else:
                col_types[col] = 'numerical'
        else:
            col_types[col] = 'categorical'
    
    return col_types

def encode_categorical_data(df, columns=None, method='onehot'):
    """
    Encode categorical columns.
    Methods: 'onehot' or 'ordinal'
    """
    if columns is None:
        col_types = detect_column_types(df)
        columns = [col for col, dtype in col_types.items() if dtype == 'categorical']
    
    if method == 'onehot':
        encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
        encoded_data = encoder.fit_transform(df[columns])
        encoded_df = pd.DataFrame(
            encoded_data,
            columns=encoder.get_feature_names_out(columns),
            index=df.index
        )

        return pd.concat([df.drop(columns, axis=1), encoded_df], axis=1)
    
    else:
        encoder = OrdinalEncoder(categories='auto', handle_unknown='use_encoded_value', unknown_value=-1)
        encoded_data = encoder.fit_transform(df[columns])
        encoded_df = pd.DataFrame(
            encoded_data,
            columns=columns,
            index=df.index
        )

        processed_df = df.copy()
        processed_df[columns] = encoded_df

        return processed_df


def scale_features(df, columns=None, method='standardize', exclude_cols=None):
    """
    Scale numerical features using standardization or normalization.
    Methods: 'standardize' or 'normalize'
    """
    if exclude_cols is None:
      exclude_cols = []

    if columns is None:
        col_types = detect_column_types(df)
        columns = [col for col, dtype in col_types.items() if dtype == 'numerical']

    columns_to_scale = [col for col in columns if col not in exclude_cols]

    if method == 'normalize':
        scaler = MinMaxScaler()
    else:
        scaler = StandardScaler()

    scaled_values = scaler.fit_transform(df[columns_to_scale])
    scaled_df = pd.DataFrame(scaled_values, columns=columns_to_scale, index=df.index)

    return pd.concat([df.drop(columns_to_scale, axis=1), scaled_df], axis=1)


def feature_selection(df, target_col, k=10, method='classification'):
    """
    Select top-k features based on target column.
    Methods: 'classification' or 'regression'
    """
    X = df.drop(target_col, axis=1)
    y = df[target_col]

    if method == 'classification':
        if X.shape[1] > k:
            selector = SelectKBest(f_classif, k=k)
        else:
            return df
    else:
        if X.shape[1] > k:
            selector = SelectKBest(f_regression, k=k)
        else:
            return df

    selected_features = selector.fit_transform(X, y)
    selected_cols = X.columns[selector.get_support()]

    return pd.DataFrame(selected_features, columns=selected_cols, index=df.index).assign(**{target_col: y})

def split_data(df, target_col, test_size=0.2, random_state=42):
    """Split data into train and test splits."""
    X = df.drop(target_col, axis=1)
    y = df[target_col]

    return train_test_split(X, y, test_size=test_size, random_state=random_state)

def correlation_matrix(df, method='pearson', threshold=0.7, plot=True):
    """
    Computes feature correlation matrix and identifies highly correlated feature pairs.
    Calculates pairwise correlations using the specified method.
    Methods: 'pearson', 'spearman', or 'kendall'
    """
    corr_matrix = df.corr(method=method)

    high_corr_pairs = []
    for i in range(len(corr_matrix.columns)):
        for j in range(i):
            if abs(corr_matrix.iloc[i, j]) > threshold:
                col1 = corr_matrix.columns[i]
                col2 = corr_matrix.columns[j]
                high_corr_pairs.append((col1, col2, corr_matrix.iloc[i, j]))
    
    if plot:
        plt.figure(figsize=(12, 10))
        sns.heatmap(
            corr_matrix,
            annot=True,
            fmt=".2f",
            cmap='coolwarm',
            vmin=-1,
            vmax=1,
            mask=np.triu(np.ones_like(corr_matrix, dtype=bool))
        )
        plt.title(f"Feature Correlation Matrix ({method.title()} method)")
        plt.tight_layout()
        plt.show()

    return corr_matrix, high_corr_pairs

def identify_proxy_variables(df, sensitive_attrs, method='absolute', threshold=0.8, top_k=3):
    """
    Identifies proxy variables for sensitive attributes using rank correlation.
    Methods: 'absolute' or 'relative'
    """
    proxy_dict = {}

    for attr in sensitive_attrs:
        if attr not in df.columns:
            continue
        
        correlations = df.corrwith(df[attr], method='spearman').abs()
        correlations = correlations.drop(sensitive_attrs, errors='ignore')

        if method == 'absolute':
            selected = correlations[correlations > threshold]
        elif method == 'relative':
            selected = correlations.sort_values(ascending=False).head(top_k)

        proxy_dict[attr] = selected.index.tolist()

    return proxy_dict



def frequency_distribution(df, sensitive_attrs, plot=True, normalize=False):
    """Analyzes distribution of sensitive attributes."""
    dist_dict = {}

    for attr in sensitive_attrs:
        if attr not in df.columns:
            continue

        dist = df[attr].value_counts(normalize=normalize).sort_index()
        dist_dict[attr] = dist

        if plot:
            plt.figure(figsize=(8, 5))
            dist.plot(kind='bar', color='skyblue')
            plt.title(f"Distribution of {attr}")
            plt.xlabel(attr)
            plt.ylabel("Proportion" if normalize else "Count")
            plt.grid(axis='y', linestyle='--', alpha=0.7)
            plt.tight_layout()
            plt.show()

    return dist_dict
